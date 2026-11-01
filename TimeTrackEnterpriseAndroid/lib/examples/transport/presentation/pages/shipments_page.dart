import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../transport_routes.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/shipment.dart';
import '../../domain/entities/transport_meta.dart';
import '../providers/transport_providers.dart';
import '../widgets/shipment_actions.dart';
import '../widgets/transport_format.dart';
import '../widgets/transport_widgets.dart';

class ShipmentsPage extends ConsumerStatefulWidget {
  const ShipmentsPage({super.key});

  @override
  ConsumerState<ShipmentsPage> createState() => _ShipmentsPageState();
}

class _ShipmentsPageState extends ConsumerState<ShipmentsPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _status = '';
  bool _onlyDrafts = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shipments = ref.watch(shipmentsProvider);
    final meta =
        ref.watch(transportMetaProvider).valueOrNull ?? TransportMeta.fallback;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(TransportRoutes.shipmentNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('شحنة جديدة'),
      ),
      body: Column(
        children: <Widget>[
          PageHero(
            title: 'الشحنات',
            subtitle: 'متابعة كل الشحنات والمسودات في مكان واحد',
            actions: <Widget>[
              HeroIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'تحديث',
                onTap: () => ref.invalidate(shipmentsProvider),
              ),
            ],
          ),
          Expanded(
            child: shipments.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorState(
                  error: error,
                  onRetry: () => ref.invalidate(shipmentsProvider),
                ),
              ),
              data: (data) {
                final all = data.value;
                final filtered = _filter(all);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(shipmentsProvider);
                    await ref.read(shipmentsProvider.future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: <Widget>[
                      if (data.fromCache) ...<Widget>[
                        const CachedBanner(),
                        const SizedBox(height: 12),
                      ],
                      _Summary(all: all),
                      const SizedBox(height: 14),
                      SearchBox(
                        controller: _search,
                        hint: 'ابحث برقم الشحنة أو العميل أو الوجهة...',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            ChoiceChip(
                              label: const Text('الكل'),
                              selected: _status.isEmpty && !_onlyDrafts,
                              onSelected: (_) => setState(() {
                                _status = '';
                                _onlyDrafts = false;
                              }),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              avatar:
                                  const Icon(Icons.edit_note_rounded, size: 17),
                              label: Text('المسودات (${_draftCount(all)})'),
                              selected: _onlyDrafts,
                              onSelected: (_) => setState(() {
                                _onlyDrafts = !_onlyDrafts;
                                _status = '';
                              }),
                            ),
                            ...(meta.flow).map(
                              (status) => Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(start: 8),
                                child: ChoiceChip(
                                  label: Text(status),
                                  selected: _status == status,
                                  onSelected: (_) => setState(() {
                                    _status = _status == status ? '' : status;
                                    _onlyDrafts = false;
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (filtered.isEmpty)
                        EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'لا توجد شحنات مطابقة',
                          subtitle: all.isEmpty
                              ? 'ابدأ بتسجيل أول استلام بضائع لتظهر الشحنة هنا.'
                              : 'جرّب تغيير البحث أو إزالة الفلاتر.',
                          action: FilledButton.icon(
                            onPressed: () =>
                                context.push(TransportRoutes.shipmentNew),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('استلام جديد'),
                          ),
                        )
                      else
                        ...filtered.map(
                          (shipment) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _ShipmentCard(
                              shipment: shipment,
                              meta: meta,
                              onOpen: () => context
                                  .push(TransportRoutes.shipment(shipment.id)),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Shipment> _filter(List<Shipment> all) {
    final query = _query.trim().toLowerCase();
    final list = all.where((shipment) {
      if (_onlyDrafts && !shipment.isDraft) return false;
      if (_status.isNotEmpty && shipment.status != _status) return false;
      if (query.isEmpty) return true;
      final haystack = <String?>[
        shipment.id,
        shipment.rog,
        shipment.waybill,
        shipment.customer,
        shipment.consignee.name,
        shipment.goods,
        shipment.from,
        shipment.to,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    list.sort((a, b) {
      final left = a.dates.receivedOrCreated;
      final right = b.dates.receivedOrCreated;
      if (left == null && right == null) return b.id.compareTo(a.id);
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return list;
  }

  static int _draftCount(List<Shipment> all) =>
      all.where((shipment) => shipment.isDraft).length;
}

class _Summary extends StatelessWidget {
  const _Summary({required this.all});

  final List<Shipment> all;

  @override
  Widget build(BuildContext context) {
    final drafts = all.where((shipment) => shipment.isDraft).length;
    final moving = all
        .where(
          (shipment) =>
              shipment.isLoaded &&
              !Shipment.finalStatuses.contains(shipment.status),
        )
        .length;
    final due = all
        .where((shipment) => !shipment.isDraft)
        .fold<double>(0, (sum, shipment) => sum + shipment.remaining);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'إجمالي الشحنات',
                value: formatNumber(all.length),
                icon: Icons.inventory_2_rounded,
                tone: const Color(0xFF1E5FA8),
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'مسودات بانتظار الاستلام',
                value: formatNumber(drafts),
                icon: Icons.edit_note_rounded,
                tone: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'شحنات قيد التنفيذ',
                value: formatNumber(moving),
                icon: Icons.local_shipping_rounded,
                tone: const Color(0xFF17795E),
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'إجمالي المستحق',
                value: formatMoney(due),
                icon: Icons.account_balance_wallet_rounded,
                tone: const Color(0xFFB3741A),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ShipmentCard extends ConsumerWidget {
  const _ShipmentCard({
    required this.shipment,
    required this.meta,
    required this.onOpen,
  });

  final Shipment shipment;
  final TransportMeta meta;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final next = meta.nextShipmentStatus(shipment.status);
    final canDelete = !shipment.isDraft &&
        !Shipment.finalStatuses.contains(shipment.status) &&
        shipment.dates.delivered == null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      shipment.urgent
                          ? Icons.priority_high_rounded
                          : Icons.inventory_2_outlined,
                      size: 19,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          shipment.id,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        Text(
                          shipment.waybill == null
                              ? shipment.customer
                              : 'بوليصة ${shipment.waybill}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(status: shipment.status, compact: true),
                  PopupMenuButton<String>(
                    tooltip: 'إجراءات',
                    onSelected: (value) => _act(context, ref, value),
                    itemBuilder: (context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'open',
                        child: Text('فتح التفاصيل'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('تعديل'),
                      ),
                      if (shipment.isDraft)
                        const PopupMenuItem<String>(
                          value: 'submit',
                          child: Text('استلام وتوليد بوليصة'),
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
                      if (shipment.tripId != null)
                        const PopupMenuItem<String>(
                          value: 'unload',
                          child: Text('إزالة من الرحلة'),
                        ),
                      if (canDelete)
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('حذف'),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          shipment.customer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'إلى: ${shipment.consignee.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${shipment.from} ← ${shipment.to}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                '${shipment.goods} · ${formatNumber(shipment.quantity)} '
                '${shipment.unit} · ${formatNumber(shipment.weight)} كجم',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 9),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.event_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatDate(shipment.dates.receivedOrCreated),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (shipment.totalFee > 0)
                    Text(
                      formatMoney(shipment.totalFee),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (shipment.remaining > 0) ...<Widget>[
                    const SizedBox(width: 8),
                    Text(
                      'متبقي ${formatMoney(shipment.remaining)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFB3741A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _act(BuildContext context, WidgetRef ref, String value) async {
    switch (value) {
      case 'open':
        onOpen();
        return;
      case 'edit':
        context.push(TransportRoutes.shipmentEdit(shipment.id));
        return;
      case 'submit':
        await submitDraftAction(context, ref, shipment);
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
        return;
    }
  }
}
