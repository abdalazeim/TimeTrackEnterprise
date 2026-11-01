import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../transport_routes.dart';
import '../../domain/entities/shipment.dart';
import '../../domain/entities/transport_meta.dart';
import '../../domain/entities/trip.dart';
import '../providers/transport_providers.dart';
import '../widgets/shipment_actions.dart';
import '../widgets/transport_format.dart';
import '../widgets/transport_widgets.dart';
import 'trips_page.dart';

class TripDetailPage extends ConsumerWidget {
  const TripDetailPage({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);
    final shipments =
        ref.watch(shipmentsProvider).valueOrNull?.value ?? const <Shipment>[];
    final meta =
        ref.watch(transportMetaProvider).valueOrNull ?? TransportMeta.fallback;

    return trips.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('مركز تحكم الرحلة')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorState(
            error: error,
            onRetry: () => ref.invalidate(tripsProvider),
          ),
        ),
      ),
      data: (data) {
        Trip? trip;
        for (final item in data.value) {
          if (item.id == tripId) {
            trip = item;
            break;
          }
        }
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('مركز تحكم الرحلة')),
            body: const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'الرحلة غير موجودة',
              subtitle: 'ربما حُذفت أو تغيّر رقمها. ارجع إلى القائمة وحدّثها.',
            ),
          );
        }
        return _TripDetailView(
          trip: trip,
          shipments: shipments,
          meta: meta,
        );
      },
    );
  }
}

class _TripDetailView extends ConsumerWidget {
  const _TripDetailView({
    required this.trip,
    required this.shipments,
    required this.meta,
  });

  final Trip trip;
  final List<Shipment> shipments;
  final TransportMeta meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final linked = tripLinkedShipments(trip, shipments);
    final loaded = linked.where((shipment) => shipment.isLoaded).toList();
    final pending = linked.where((shipment) => !shipment.isLoaded).toList();
    final used = tripLoadedWeight(trip, shipments);
    final remaining = (trip.capacityKg - used).clamp(0, double.infinity);
    final ratio =
        trip.capacityKg <= 0 ? 0.0 : (used / trip.capacityKg).clamp(0, 1);
    final eligible = shipments
        .where(
          (shipment) =>
              !shipment.isDraft &&
              (shipment.tripId == null || shipment.tripId!.isEmpty) &&
              (shipment.status == 'تم الاستلام' ||
                  shipment.status == 'جاهزة للشحن'),
        )
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('الرحلة ${trip.id}'),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'إجراءات',
            onSelected: (value) => _act(context, ref, value),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'edit',
                child: Text('تعديل الرحلة'),
              ),
              if (trip.canAdvance)
                PopupMenuItem<String>(
                  value: 'advance',
                  child: Text(
                    'نقل إلى: ${meta.nextTripStatus(trip.status)}',
                  ),
                ),
              if (!trip.closed)
                const PopupMenuItem<String>(
                  value: 'close',
                  child: Text('إقفال الرحلة'),
                ),
              if (trip.closed)
                const PopupMenuItem<String>(
                  value: 'reopen',
                  child: Text('إعادة فتح الرحلة'),
                ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('حذف الرحلة'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: () {
              ref.invalidate(tripsProvider);
              ref.invalidate(shipmentsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(tripsProvider);
          ref.invalidate(shipmentsProvider);
          await ref.read(tripsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: <Widget>[
            _TripHeader(trip: trip),
            const SizedBox(height: 12),
            SectionCard(
              title: 'السعة والتحميل',
              subtitle:
                  'يُحسب المحمّل من الشحنات التي حالتها «تم الشحن» أو ما بعدها.',
              icon: Icons.speed_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: ratio.toDouble(),
                      minHeight: 10,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      color: ratio >= 0.95
                          ? const Color(0xFFB3741A)
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Text(
                        '${formatNumber(used)} / '
                        '${formatNumber(trip.capacityKg)} كجم',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${formatNumber(remaining)} كجم متاحة',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = (constraints.maxWidth - 16) / 3;
                      return Row(
                        children: <Widget>[
                          SizedBox(
                            width: width,
                            child: _MiniMetric(
                              label: 'محمّلة',
                              value: formatNumber(loaded.length),
                              color: const Color(0xFF17795E),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: width,
                            child: _MiniMetric(
                              label: 'مرتبطة',
                              value: formatNumber(pending.length),
                              color: const Color(0xFFB3741A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: width,
                            child: _MiniMetric(
                              label: 'المتبقي',
                              value: formatNumber(remaining),
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (!trip.closed) ...<Widget>[
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: eligible.isEmpty
                                ? null
                                : () => _openLinkSheet(context, ref, eligible),
                            icon: const Icon(Icons.link_rounded, size: 18),
                            label: Text(
                              'ربط شحنات (${eligible.length})',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: pending.isEmpty
                                ? null
                                : () => _openLoadSheet(
                                      context,
                                      ref,
                                      pending,
                                      remaining,
                                    ),
                            icon: const Icon(
                              Icons.local_shipping_rounded,
                              size: 18,
                            ),
                            label: const Text('تأكيد التحميل'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'شحنات الرحلة',
              subtitle: '${linked.length} شحنة مرتبطة بهذه الرحلة',
              icon: Icons.inventory_2_outlined,
              child: linked.isEmpty
                  ? EmptyState(
                      icon: Icons.inbox_rounded,
                      title: 'لا توجد شحنات مرتبطة',
                      subtitle: eligible.isEmpty
                          ? 'لا توجد شحنات مستلمة متاحة للربط حاليًا.'
                          : 'استخدم «ربط شحنات» لإضافة الشحنات الجاهزة.',
                      action: eligible.isEmpty || trip.closed
                          ? null
                          : FilledButton.icon(
                              onPressed: () =>
                                  _openLinkSheet(context, ref, eligible),
                              icon: const Icon(Icons.link_rounded, size: 18),
                              label: const Text('ربط شحنات'),
                            ),
                    )
                  : Column(
                      children: <Widget>[
                        for (final shipment in linked)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TripShipmentTile(
                              shipment: shipment,
                              canUnload: !trip.closed &&
                                  !Shipment.finalStatuses.contains(
                                    shipment.status,
                                  ),
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'سجل الرحلة',
              icon: Icons.timeline_rounded,
              child: Column(
                children: <Widget>[
                  _TripStep(
                    label: 'التخطيط',
                    date: trip.dates.plan,
                    last: false,
                  ),
                  _TripStep(
                    label: 'التحميل',
                    date: trip.dates.load,
                    last: false,
                  ),
                  _TripStep(
                    label: 'الانطلاق',
                    date: trip.dates.depart,
                    last: false,
                  ),
                  _TripStep(
                    label: 'الوصول للوجهة',
                    date: trip.dates.arrive,
                    last: true,
                  ),
                ],
              ),
            ),
            if ((trip.note ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              SectionCard(
                title: 'ملاحظات',
                icon: Icons.notes_rounded,
                child: Text(
                  trip.note!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ),
            ],
            const SizedBox(height: 18),
            _TripActions(trip: trip, meta: meta),
          ],
        ),
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, String value) async {
    switch (value) {
      case 'edit':
        context.push(TransportRoutes.tripEdit(trip.id));
        return;
      case 'advance':
        await _advance(context, ref);
        return;
      case 'close':
        await _close(context, ref);
        return;
      case 'reopen':
        await _reopen(context, ref);
        return;
      case 'delete':
        await _delete(context, ref);
        return;
    }
  }

  Future<void> _advance(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(transportRepositoryProvider).advanceTrip(trip.id);
      invalidateTransportData(ref, goods: false);
      if (!context.mounted) return;
      showSuccessSnack(context, 'تم تحديث حالة الرحلة');
    } catch (error) {
      if (!context.mounted) return;
      showErrorSnack(context, error);
    }
  }

  Future<void> _close(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'إقفال الرحلة',
      message: 'سيتم إقفال الرحلة ${trip.id} ومنع أي تعديل أو ربط جديد. '
          'يمكن إعادة فتحها لاحقًا.',
      confirmLabel: 'إقفال',
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(transportRepositoryProvider).closeTrip(trip.id);
      invalidateTransportData(ref, goods: false);
      if (!context.mounted) return;
      showSuccessSnack(context, 'تم إقفال الرحلة');
    } catch (error) {
      if (!context.mounted) return;
      showErrorSnack(context, error);
    }
  }

  Future<void> _reopen(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(transportRepositoryProvider).reopenTrip(trip.id);
      invalidateTransportData(ref, goods: false);
      if (!context.mounted) return;
      showSuccessSnack(context, 'تمت إعادة فتح الرحلة');
    } catch (error) {
      if (!context.mounted) return;
      showErrorSnack(context, error);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'حذف الرحلة',
      message: 'سيتم حذف الرحلة ${trip.id} نهائيًا. الشحنات المرتبطة تُفصل '
          'ولا تُحذف. لا يمكن التراجع.',
      confirmLabel: 'حذف نهائي',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(transportRepositoryProvider).deleteTrip(trip.id);
      invalidateTransportData(ref, goods: false);
      if (!context.mounted) return;
      showSuccessSnack(context, 'تم حذف الرحلة');
      context.pop();
    } catch (error) {
      if (!context.mounted) return;
      showErrorSnack(context, error);
    }
  }

  Future<void> _openLoadSheet(
    BuildContext context,
    WidgetRef ref,
    List<Shipment> pending,
    num remaining,
  ) async {
    final loaded = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _LoadSheet(
        trip: trip,
        pending: pending,
        remaining: remaining,
      ),
    );
    if (loaded != null && context.mounted) {
      showSuccessSnack(context, 'تم تحميل $loaded شحنة على الرحلة');
    }
  }

  Future<void> _openLinkSheet(
    BuildContext context,
    WidgetRef ref,
    List<Shipment> eligible,
  ) async {
    final linked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _LinkSheet(
        trip: trip,
        eligible: eligible,
        remaining: (trip.capacityKg - tripLoadedWeight(trip, shipments))
            .clamp(0, double.infinity),
      ),
    );
    if (linked != null && context.mounted) {
      showSuccessSnack(context, 'تم ربط $linked شحنة بالرحلة');
    }
  }
}

class _TripHeader extends StatelessWidget {
  const _TripHeader({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            scheme.primary,
            scheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  trip.name.isEmpty ? trip.id : trip.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  trip.closed ? 'مقفلة' : trip.status,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${trip.id} · ${trip.from} ← ${trip.to}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _HeaderItem(
                icon: Icons.local_shipping_outlined,
                label: trip.vehicle.isEmpty ? 'بدون مركبة' : trip.vehicle,
              ),
              const SizedBox(width: 8),
              _HeaderItem(
                icon: Icons.badge_outlined,
                label: trip.driver.isEmpty ? 'بدون سائق' : trip.driver,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              _HeaderItem(
                icon: Icons.event_rounded,
                label: formatDateTime(trip.dates.plan),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderItem extends StatelessWidget {
  const _HeaderItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TripShipmentTile extends ConsumerWidget {
  const _TripShipmentTile({
    required this.shipment,
    required this.canUnload,
  });

  final Shipment shipment;
  final bool canUnload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  onTap: () =>
                      context.push(TransportRoutes.shipment(shipment.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        shipment.id,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${shipment.customer} · إلى ${shipment.consignee.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              StatusChip(status: shipment.status, compact: true),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${shipment.from} ← ${shipment.to} · ${shipment.goods}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Text(
                '${formatNumber(shipment.weight, decimals: 1)} كجم',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (canUnload) ...<Widget>[
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => unloadShipmentAction(context, ref, shipment),
                icon: const Icon(Icons.link_off_rounded, size: 16),
                label: const Text('إزالة من الرحلة'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TripStep extends StatelessWidget {
  const _TripStep({
    required this.label,
    required this.date,
    required this.last,
  });

  final String label;
  final DateTime? date;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = date != null;
    final color =
        done ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          children: <Widget>[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: done ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: done
                  ? const Icon(Icons.check, size: 9, color: Colors.white)
                  : null,
            ),
            if (!last)
              Container(
                width: 2,
                height: 32,
                color: color.withValues(alpha: 0.4),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                Text(
                  done ? formatDateTime(date) : 'لم تُسجل بعد',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TripActions extends ConsumerWidget {
  const _TripActions({required this.trip, required this.meta});

  final Trip trip;
  final TransportMeta meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: <Widget>[
        if (trip.canAdvance)
          FilledButton.icon(
            onPressed: () async {
              try {
                await ref
                    .read(transportRepositoryProvider)
                    .advanceTrip(trip.id);
                invalidateTransportData(ref, goods: false);
                if (!context.mounted) return;
                showSuccessSnack(context, 'تم تحديث حالة الرحلة');
              } catch (error) {
                if (!context.mounted) return;
                showErrorSnack(context, error);
              }
            },
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text('نقل إلى: ${meta.nextTripStatus(trip.status)}'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        if (trip.canAdvance) const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push(TransportRoutes.tripEdit(trip.id)),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('تعديل'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    if (trip.closed) {
                      await ref
                          .read(transportRepositoryProvider)
                          .reopenTrip(trip.id);
                    } else {
                      await ref
                          .read(transportRepositoryProvider)
                          .closeTrip(trip.id);
                    }
                    invalidateTransportData(ref, goods: false);
                    if (!context.mounted) return;
                    showSuccessSnack(
                      context,
                      trip.closed ? 'تمت إعادة فتح الرحلة' : 'تم إقفال الرحلة',
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    showErrorSnack(context, error);
                  }
                },
                icon: Icon(
                  trip.closed
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  size: 18,
                ),
                label: Text(trip.closed ? 'إعادة فتح' : 'إقفال'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LinkSheet extends ConsumerStatefulWidget {
  const _LinkSheet({
    required this.trip,
    required this.eligible,
    required this.remaining,
  });

  final Trip trip;
  final List<Shipment> eligible;
  final num remaining;

  @override
  ConsumerState<_LinkSheet> createState() => _LinkSheetState();
}

class _LinkSheetState extends ConsumerState<_LinkSheet> {
  final Set<String> _selected = <String>{};
  bool _busy = false;

  double get _selectedWeight => widget.eligible
      .where((shipment) => _selected.contains(shipment.id))
      .fold<double>(0, (sum, shipment) => sum + shipment.weight);

  bool get _overCapacity => _selectedWeight > widget.remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'ربط شحنات بالرحلة',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'السعة المتاحة ${formatNumber(widget.remaining)} كجم — '
              'المحدد ${formatNumber(_selectedWeight)} كجم',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _overCapacity
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => setState(() {
                    _selected
                      ..clear()
                      ..addAll(widget.eligible.map((shipment) => shipment.id));
                  }),
                  child: const Text('تحديد الكل'),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('إلغاء التحديد'),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.eligible.length,
                itemBuilder: (context, index) {
                  final shipment = widget.eligible[index];
                  final checked = _selected.contains(shipment.id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selected.add(shipment.id);
                      } else {
                        _selected.remove(shipment.id);
                      }
                    }),
                    title: Text(
                      '${shipment.customer} — ${shipment.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${shipment.from} ← ${shipment.to} · '
                      '${formatNumber(shipment.weight, decimals: 1)} كجم',
                    ),
                    secondary: StatusChip(
                      status: shipment.status,
                      compact: true,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
            if (_overCapacity)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'الوزن المحدد يتجاوز السعة المتاحة. يمكنك ربطها الآن، لكن لن '
                  'يُسمح بتحميلها حتى تتوفر سعة كافية.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            FilledButton.icon(
              onPressed: _busy || _selected.isEmpty ? null : _link,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link_rounded, size: 19),
              label: Text('ربط ${_selected.length} شحنة'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _link() async {
    setState(() => _busy = true);
    try {
      await ref.read(transportRepositoryProvider).linkShipments(
            widget.trip.id,
            _selected.toList(growable: false),
          );
      invalidateTransportData(ref, goods: false);
      if (!mounted) return;
      Navigator.of(context).pop(_selected.length);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnack(context, error);
    }
  }
}

/// لوحة تحميل الشحنات المرتبطة، بنفس قاعدة السعة التي تفرضها واجهة الويب:
/// لا يُسمح بالتحميل إذا تجاوز الوزن المحدد السعة المتبقية للمركبة.
class _LoadSheet extends ConsumerStatefulWidget {
  const _LoadSheet({
    required this.trip,
    required this.pending,
    required this.remaining,
  });

  final Trip trip;
  final List<Shipment> pending;
  final num remaining;

  @override
  ConsumerState<_LoadSheet> createState() => _LoadSheetState();
}

class _LoadSheetState extends ConsumerState<_LoadSheet> {
  final Set<String> _selected = <String>{};
  bool _busy = false;

  double get _selectedWeight => widget.pending
      .where((shipment) => _selected.contains(shipment.id))
      .fold<double>(0, (sum, shipment) => sum + shipment.weight);

  bool get _overCapacity => _selectedWeight > widget.remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'تأكيد تحميل شحنات الرحلة',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'السعة المتاحة ${formatNumber(widget.remaining)} كجم — '
              'المحدد ${formatNumber(_selectedWeight)} كجم',
              style: theme.textTheme.bodySmall?.copyWith(
                color: _overCapacity
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => setState(() {
                    _selected
                      ..clear()
                      ..addAll(
                        widget.pending.map((shipment) => shipment.id),
                      );
                  }),
                  child: const Text('تحديد الكل'),
                ),
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('إلغاء التحديد'),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.pending.length,
                itemBuilder: (context, index) {
                  final shipment = widget.pending[index];
                  final checked = _selected.contains(shipment.id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selected.add(shipment.id);
                      } else {
                        _selected.remove(shipment.id);
                      }
                    }),
                    title: Text(
                      '${shipment.customer} — ${shipment.id}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${shipment.from} ← ${shipment.to} · '
                      '${formatNumber(shipment.weight, decimals: 1)} كجم',
                    ),
                    secondary: StatusChip(
                      status: shipment.status,
                      compact: true,
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
            if (_overCapacity)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'لا يمكن إتمام التحميل — الوزن المطلوب يتجاوز السعة المتبقية '
                  'للمركبة.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            FilledButton.icon(
              onPressed:
                  _busy || _selected.isEmpty || _overCapacity ? null : _load,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.local_shipping_rounded, size: 19),
              label: Text('تحميل ${_selected.length} شحنة'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      await ref.read(transportRepositoryProvider).loadShipments(
            widget.trip.id,
            _selected.toList(growable: false),
          );
      invalidateTransportData(ref, goods: false);
      if (!mounted) return;
      Navigator.of(context).pop(_selected.length);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnack(context, error);
    }
  }
}
