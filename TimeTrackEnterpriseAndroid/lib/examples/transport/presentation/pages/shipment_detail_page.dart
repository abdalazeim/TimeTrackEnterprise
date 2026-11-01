import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../transport_routes.dart';
import '../../domain/entities/shipment.dart';
import '../../domain/entities/transport_meta.dart';
import '../providers/transport_providers.dart';
import '../widgets/shipment_actions.dart';
import '../widgets/signature_pad.dart';
import '../widgets/transport_format.dart';
import '../widgets/transport_widgets.dart';

class ShipmentDetailPage extends ConsumerWidget {
  const ShipmentDetailPage({required this.shipmentId, super.key});

  final String shipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipments = ref.watch(shipmentsProvider);
    final meta =
        ref.watch(transportMetaProvider).valueOrNull ?? TransportMeta.fallback;

    return shipments.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الشحنة')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorState(
            error: error,
            onRetry: () => ref.invalidate(shipmentsProvider),
          ),
        ),
      ),
      data: (data) {
        Shipment? shipment;
        for (final item in data.value) {
          if (item.id == shipmentId) {
            shipment = item;
            break;
          }
        }
        if (shipment == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('تفاصيل الشحنة')),
            body: const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'الشحنة غير موجودة',
              subtitle:
                  'ربما حُذفت أو تغيّر رقمها. حدّث القائمة وحاول مرة أخرى.',
            ),
          );
        }
        return _ShipmentDetailView(
          shipment: shipment,
          meta: meta,
          fromCache: data.fromCache,
        );
      },
    );
  }
}

class _ShipmentDetailView extends ConsumerWidget {
  const _ShipmentDetailView({
    required this.shipment,
    required this.meta,
    required this.fromCache,
  });

  final Shipment shipment;
  final TransportMeta meta;
  final bool fromCache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final next = meta.nextShipmentStatus(shipment.status);
    final canDelete = !shipment.isDraft &&
        !Shipment.finalStatuses.contains(shipment.status) &&
        shipment.dates.delivered == null;
    final canPod = !shipment.isDraft &&
        shipment.status != 'ملغاة' &&
        shipment.status != 'مكتملة' &&
        shipment.pod?.hasSignature != true;

    return Scaffold(
      appBar: AppBar(
        title: Text('الشحنة ${shipment.id}'),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'إجراءات',
            onSelected: (value) => _act(context, ref, value),
            itemBuilder: (context) => <PopupMenuEntry<String>>[
              if (shipment.isDraft)
                const PopupMenuItem<String>(
                  value: 'submit',
                  child: Text('استلام وتوليد بوليصة'),
                ),
              const PopupMenuItem<String>(
                value: 'edit',
                child: Text('تعديل البيانات'),
              ),
              if (next.isNotEmpty)
                PopupMenuItem<String>(
                  value: 'advance',
                  child: Text('نقل إلى: $next'),
                ),
              if (!shipment.isDraft)
                const PopupMenuItem<String>(
                  value: 'except',
                  child: Text('حالة استثنائية'),
                ),
              if (shipment.tripId != null && !shipment.isLoaded)
                const PopupMenuItem<String>(
                  value: 'unload',
                  child: Text('إزالة من الرحلة'),
                ),
              if (canDelete)
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('حذف الشحنة'),
                ),
            ],
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(shipmentsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: <Widget>[
          if (fromCache) ...<Widget>[
            const CachedBanner(),
            const SizedBox(height: 12),
          ],
          _Header(shipment: shipment),
          const SizedBox(height: 12),
          SectionCard(
            title: 'المسار',
            icon: Icons.route_rounded,
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _RouteCity(
                        label: 'من',
                        city: shipment.from,
                        icon: Icons.trip_origin_rounded,
                      ),
                    ),
                    Icon(
                      Icons.arrow_back_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    Expanded(
                      child: _RouteCity(
                        label: 'إلى',
                        city: shipment.to,
                        icon: Icons.place_rounded,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                KeyValueRow(
                  label: 'المسافة',
                  value: shipment.distance == 0
                      ? '—'
                      : '${formatNumber(shipment.distance, decimals: 1)} كم',
                  icon: Icons.straighten_rounded,
                ),
                KeyValueRow(
                  label: 'المركبة',
                  value: shipment.vehicle ?? '—',
                  icon: Icons.local_shipping_outlined,
                ),
                KeyValueRow(
                  label: 'السائق',
                  value: shipment.driver ?? '—',
                  icon: Icons.badge_outlined,
                ),
                KeyValueRow(
                  label: 'الرحلة',
                  value: shipment.tripId ?? 'غير مرتبطة برحلة',
                  icon: Icons.route_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'الأطراف',
            icon: Icons.people_alt_outlined,
            child: Column(
              children: <Widget>[
                _PartyBlock(
                  title: 'المرسل / الشاحن',
                  name: shipment.shipper.name.isEmpty
                      ? shipment.customer
                      : shipment.shipper.name,
                  phone: shipment.shipper.phone,
                  notes: shipment.shipper.notes,
                ),
                const Divider(height: 22),
                _PartyBlock(
                  title: 'المرسل إليه / المستلم',
                  name: shipment.consignee.name,
                  phone: shipment.consignee.phone,
                  notes: shipment.consignee.notes,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'بنود البضاعة',
            subtitle: shipment.goods,
            icon: Icons.inventory_2_outlined,
            child: Column(
              children: <Widget>[
                if (shipment.items.isEmpty)
                  KeyValueRow(
                    label: shipment.goods,
                    value:
                        '${formatNumber(shipment.quantity)} ${shipment.unit}',
                  )
                else
                  for (final item in shipment.items)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0x11000000)),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  item.goods,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (item.note != null && item.note!.isNotEmpty)
                                  Text(
                                    item.note!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${formatNumber(item.qty, decimals: 2)} ${item.unit}',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${formatNumber(item.weight, decimals: 2)} كجم',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (item.discount > 0) ...<Widget>[
                            const SizedBox(width: 8),
                            Text(
                              '−${formatMoney(item.discount)}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MiniStat(
                        label: 'الوزن',
                        value:
                            '${formatNumber(shipment.weight, decimals: 2)} كجم',
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        label: 'الحجم',
                        value:
                            '${formatNumber(shipment.volume, decimals: 2)} م³',
                      ),
                    ),
                    Expanded(
                      child: _MiniStat(
                        label: 'الخدمات',
                        value: shipment.services.isEmpty
                            ? '—'
                            : '${shipment.services.length}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'الأجرة والدفع',
            icon: Icons.receipt_long_outlined,
            child: Column(
              children: <Widget>[
                KeyValueRow(
                  label: 'الأجرة الأساسية',
                  value: formatMoney(shipment.fee.base),
                ),
                KeyValueRow(
                  label: 'رسوم الوزن',
                  value: formatMoney(shipment.fee.weight),
                ),
                KeyValueRow(
                  label: 'الخدمات',
                  value: formatMoney(shipment.fee.services),
                ),
                KeyValueRow(
                  label: 'الخصم',
                  value: '−${formatMoney(shipment.fee.discount)}',
                ),
                const Divider(height: 20),
                KeyValueRow(
                  label: 'الإجمالي',
                  value: formatMoney(shipment.totalFee),
                  valueColor: theme.colorScheme.primary,
                ),
                KeyValueRow(
                  label: 'المدفوع',
                  value: formatMoney(shipment.paid),
                ),
                KeyValueRow(
                  label: 'المتبقي',
                  value: formatMoney(shipment.remaining),
                  valueColor: shipment.remaining > 0
                      ? const Color(0xFFB3741A)
                      : const Color(0xFF17795E),
                ),
                KeyValueRow(
                  label: 'طريقة الدفع',
                  value: shipment.method ?? '—',
                  icon: Icons.payments_outlined,
                ),
                KeyValueRow(
                  label: 'حالة السداد',
                  value: shipment.paymentState,
                  icon: Icons.verified_outlined,
                ),
                if (shipment.invoiceNumber != null)
                  KeyValueRow(
                    label: 'الفاتورة',
                    value: shipment.invoiceNumber!,
                    icon: Icons.description_outlined,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'سجل المراحل',
            icon: Icons.timeline_rounded,
            child: Column(
              children: <Widget>[
                for (var index = 0;
                    index < shipment.dates.steps.length;
                    index++)
                  _TimelineStep(
                    label: shipment.dates.steps[index].$1,
                    date: shipment.dates.steps[index].$2,
                    last: index == shipment.dates.steps.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'إثبات التسليم',
            subtitle: shipment.pod?.hasSignature == true
                ? 'موقّع ومحفوظ'
                : 'لم يُوثّق بعد',
            icon: Icons.draw_outlined,
            child: shipment.pod?.hasSignature == true
                ? _PodView(pod: shipment.pod!)
                : Column(
                    children: <Widget>[
                      Text(
                        'يمكن التقاط توقيع المستلم وتوثيق اسمه ورقم بطاقته '
                        'قبل إقفال الشحنة.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: canPod ? () => _openPod(context, ref) : null,
                        icon: const Icon(Icons.draw_rounded, size: 18),
                        label: const Text('توثيق التسليم'),
                      ),
                    ],
                  ),
          ),
          if (shipment.notes != null && shipment.notes!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: 'ملاحظات',
              icon: Icons.notes_rounded,
              child: Text(
                shipment.notes!,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _Actions(
            shipment: shipment,
            next: next,
            canDelete: canDelete,
            canPod: canPod,
            onAdvance: () => advanceShipmentAction(context, ref, shipment),
            onSubmit: () => submitDraftAction(context, ref, shipment),
            onEdit: () =>
                context.push(TransportRoutes.shipmentEdit(shipment.id)),
            onException: () =>
                shipmentExceptionAction(context, ref, shipment, meta),
            onPod: () => _openPod(context, ref),
            onUnload: shipment.tripId == null
                ? null
                : () => unloadShipmentAction(context, ref, shipment),
            onDelete: canDelete
                ? () => deleteShipmentAction(context, ref, shipment)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, String value) async {
    switch (value) {
      case 'submit':
        await submitDraftAction(context, ref, shipment);
        return;
      case 'edit':
        context.push(TransportRoutes.shipmentEdit(shipment.id));
        return;
      case 'advance':
        await advanceShipmentAction(context, ref, shipment);
        return;
      case 'except':
        await shipmentExceptionAction(context, ref, shipment, meta);
        return;
      case 'unload':
        await unloadShipmentAction(context, ref, shipment);
        return;
      case 'delete':
        await deleteShipmentAction(context, ref, shipment);
        if (context.mounted) context.pop();
        return;
    }
  }

  Future<void> _openPod(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PodSheet(shipment: shipment),
    );
    if (saved == true && context.mounted) {
      showSuccessSnack(context, 'تم حفظ إثبات التسليم');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.shipment});

  final Shipment shipment;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      shipment.id,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      shipment.waybill == null
                          ? 'بدون بوليصة بعد'
                          : 'بوليصة ${shipment.waybill}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
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
                  shipment.status,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            shipment.customer,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${shipment.from} ← ${shipment.to}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _HeaderChip(
                icon: Icons.inventory_2_outlined,
                text:
                    '${shipment.goods} · ${formatNumber(shipment.quantity)} ${shipment.unit}',
              ),
              const SizedBox(width: 8),
              _HeaderChip(
                icon: Icons.scale_outlined,
                text: '${formatNumber(shipment.weight)} كجم',
              ),
              if (shipment.urgent) ...<Widget>[
                const SizedBox(width: 8),
                const _HeaderChip(
                  icon: Icons.priority_high_rounded,
                  text: 'مستعجلة',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

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
                text,
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

class _RouteCity extends StatelessWidget {
  const _RouteCity({
    required this.label,
    required this.city,
    required this.icon,
    this.alignEnd = false,
  });

  final String label;
  final String city;
  final IconData icon;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                city,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PartyBlock extends StatelessWidget {
  const _PartyBlock({
    required this.title,
    required this.name,
    this.phone,
    this.notes,
  });

  final String title;
  final String name;
  final String? phone;
  final String? notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          name.isEmpty ? '—' : name,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (phone != null && phone!.isNotEmpty)
          Text(
            phone!,
            textDirection: TextDirection.ltr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (notes != null && notes!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 3),
          Text(
            notes!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(
          value,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
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
                height: 34,
                color: color.withValues(alpha: 0.4),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: done ? FontWeight.w700 : FontWeight.w400,
                    color: done
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
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

class _PodView extends StatelessWidget {
  const _PodView({required this.pod});

  final ShipmentPod pod;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PodSignature(dataUrl: pod.signature!),
        const SizedBox(height: 10),
        KeyValueRow(label: 'المستلم', value: pod.receiver ?? '—'),
        KeyValueRow(label: 'رقم البطاقة', value: pod.cardId ?? '—'),
        KeyValueRow(label: 'التسليم بواسطة', value: pod.by ?? '—'),
        KeyValueRow(label: 'التاريخ', value: formatDateTime(pod.date)),
        if (pod.note != null && pod.note!.isNotEmpty)
          KeyValueRow(label: 'ملاحظة', value: pod.note!),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.shipment,
    required this.next,
    required this.canDelete,
    required this.canPod,
    required this.onAdvance,
    required this.onSubmit,
    required this.onEdit,
    required this.onException,
    required this.onPod,
    required this.onUnload,
    required this.onDelete,
  });

  final Shipment shipment;
  final String next;
  final bool canDelete;
  final bool canPod;
  final VoidCallback onAdvance;
  final VoidCallback onSubmit;
  final VoidCallback onEdit;
  final VoidCallback onException;
  final VoidCallback onPod;
  final VoidCallback? onUnload;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (shipment.isDraft) {
      return Column(
        children: <Widget>[
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.move_to_inbox_rounded),
            label: const Text('استلام وتوليد بوليصة'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('تعديل المسودة'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('حذف المسودة'),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        if (next.isNotEmpty)
          FilledButton.icon(
            onPressed: onAdvance,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text('نقل إلى: $next'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        if (next.isNotEmpty) const SizedBox(height: 8),
        if (canPod)
          FilledButton.tonalIcon(
            onPressed: onPod,
            icon: const Icon(Icons.draw_rounded),
            label: const Text('توثيق إثبات التسليم'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        if (canPod) const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('تعديل'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onException,
                icon: const Icon(Icons.report_problem_outlined, size: 18),
                label: const Text('استثناء'),
              ),
            ),
          ],
        ),
        if (onUnload != null) ...<Widget>[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onUnload,
            icon: const Icon(Icons.link_off_rounded, size: 18),
            label: const Text('إزالة من الرحلة'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
            ),
          ),
        ],
        if (canDelete) ...<Widget>[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('حذف الشحنة'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _PodSheet extends ConsumerStatefulWidget {
  const _PodSheet({required this.shipment});

  final Shipment shipment;

  @override
  ConsumerState<_PodSheet> createState() => _PodSheetState();
}

class _PodSheetState extends ConsumerState<_PodSheet> {
  final SignaturePadController _pad = SignaturePadController();
  late final TextEditingController _receiver = TextEditingController(
    text: widget.shipment.pod?.receiver ?? widget.shipment.consignee.name,
  );
  late final TextEditingController _card = TextEditingController(
    text: widget.shipment.pod?.cardId ?? widget.shipment.consignee.cardId ?? '',
  );
  late final TextEditingController _by =
      TextEditingController(text: widget.shipment.pod?.by ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.shipment.pod?.note ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _pad.dispose();
    _receiver.dispose();
    _card.dispose();
    _by.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'إثبات تسليم ${widget.shipment.id}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'وقّع المستلم داخل المربع، ثم أكمل بياناته واحفظ الإثبات.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SignaturePad(controller: _pad),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: () => _pad.clear(),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: const Text('مسح التوقيع'),
                ),
                const Spacer(),
                Text(
                  'PNG',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _receiver,
              decoration: const InputDecoration(
                labelText: 'اسم المستلم *',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _card,
              decoration: const InputDecoration(
                labelText: 'رقم البطاقة / الهوية',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _by,
              decoration: const InputDecoration(
                labelText: 'تم التسليم بواسطة',
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظة التسليم',
                hintText: 'حالة البضاعة عند الاستلام...',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 19),
              label: const Text('حفظ إثبات التسليم'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final receiver = _receiver.text.trim();
    if (receiver.isEmpty) {
      showErrorSnack(context, StateError('أدخل اسم المستلم.'));
      return;
    }
    if (_pad.isEmpty) {
      showErrorSnack(context, StateError('وقّع المستلم قبل الحفظ.'));
      return;
    }

    setState(() => _busy = true);
    try {
      final signature = await _pad.toPngDataUrl();
      await ref.read(transportRepositoryProvider).savePod(
        widget.shipment.id,
        <String, dynamic>{
          'receiver': receiver,
          'recId': _card.text.trim(),
          'by': _by.text.trim(),
          'note': _note.text.trim(),
          'sig': signature,
        },
      );
      invalidateTransportData(ref, goods: false);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnack(context, error);
    }
  }
}
