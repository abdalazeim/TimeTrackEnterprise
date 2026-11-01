import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../transport_routes.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/shipment.dart';
import '../providers/transport_providers.dart';
import '../widgets/shipment_actions.dart';
import '../widgets/transport_format.dart';
import '../widgets/transport_widgets.dart';

class ReceivingPage extends ConsumerWidget {
  const ReceivingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipments = ref.watch(shipmentsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(TransportRoutes.shipmentNew),
        icon: const Icon(Icons.move_to_inbox_rounded),
        label: const Text('استلام جديد'),
      ),
      body: Column(
        children: <Widget>[
          PageHero(
            title: 'استلام بضائع',
            subtitle: 'المسودات والشحنات الجاهزة للتحميل',
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
                final drafts = data.value
                    .where((shipment) => shipment.isDraft)
                    .toList(growable: false);
                final ready = data.value
                    .where(
                      (shipment) =>
                          !shipment.isDraft &&
                          (shipment.status == 'تم الاستلام' ||
                              shipment.status == 'جاهزة للشحن'),
                    )
                    .toList(growable: false);
                final draftsWeight = drafts.fold<double>(
                  0,
                  (sum, shipment) => sum + shipment.weight,
                );

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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = (constraints.maxWidth - 10) / 2;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              SizedBox(
                                width: width,
                                child: MetricTile(
                                  label: 'مسودات تنتظر الاستلام',
                                  value: formatNumber(drafts.length),
                                  icon: Icons.edit_note_rounded,
                                  tone: const Color(0xFF6B7280),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: MetricTile(
                                  label: 'وزن المسودات',
                                  value: '${formatNumber(draftsWeight)} كجم',
                                  icon: Icons.scale_rounded,
                                  tone: const Color(0xFFB3741A),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: MetricTile(
                                  label: 'مستلمة وجاهزة للشحن',
                                  value: formatNumber(ready.length),
                                  icon: Icons.inventory_rounded,
                                  tone: const Color(0xFF1E5FA8),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: MetricTile(
                                  label: 'إجمالي السجلات',
                                  value: formatNumber(data.value.length),
                                  icon: Icons.receipt_long_rounded,
                                  tone: const Color(0xFF17795E),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      SectionCard(
                        title: 'المسودات',
                        subtitle:
                            'أكمل بيانات أي مسودة ثم اضغط «استلام» لتوليد البوليصة والفاتورة.',
                        icon: Icons.edit_note_rounded,
                        child: drafts.isEmpty
                            ? const EmptyState(
                                icon: Icons.check_circle_outline_rounded,
                                title: 'لا توجد مسودات معلّقة',
                                subtitle:
                                    'كل عمليات الاستلام السابقة تم اعتمادها.',
                              )
                            : Column(
                                children: <Widget>[
                                  for (final draft in drafts)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _DraftCard(draft: draft),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        title: 'مستلمة وتنتظر التحميل',
                        subtitle:
                            'هذه الشحنات استُلمت بالفعل وتحتاج ربطها برحلة قبل الشحن.',
                        icon: Icons.local_shipping_outlined,
                        child: ready.isEmpty
                            ? const EmptyState(
                                icon: Icons.inbox_rounded,
                                title: 'لا توجد شحنات بانتظار التحميل',
                                subtitle:
                                    'ستظهر هنا الشحنات المستلمة التي لم تُربط برحلة.',
                              )
                            : Column(
                                children: <Widget>[
                                  for (final shipment in ready)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _ReadyCard(shipment: shipment),
                                    ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: Theme.of(context)
                            .colorScheme
                            .secondaryContainer
                            .withValues(alpha: 0.45),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Icon(Icons.info_outline_rounded, size: 19),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  '«استلام وتوليد بوليصة» يرسل العملية إلى الخادم '
                                  'ويصدر البوليصة والفاتورة ويسجل الدفعة الأولى. '
                                  '«حفظ كمسودة» يحفظ البيانات فقط ويمكن استكمالها لاحقًا.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(height: 1.6),
                                ),
                              ),
                            ],
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
}

class _DraftCard extends ConsumerWidget {
  const _DraftCard({required this.draft});

  final Shipment draft;

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      draft.id,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      draft.customer.isEmpty ? 'بدون عميل' : draft.customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const StatusChip(status: 'مسودة', compact: true),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${draft.from} ← ${draft.to} · ${draft.goods} · '
            '${formatNumber(draft.weight, decimals: 1)} كجم',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      context.push(TransportRoutes.shipmentEdit(draft.id)),
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('متابعة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => submitDraftAction(context, ref, draft),
                  icon: const Icon(Icons.check_rounded, size: 17),
                  label: const Text('استلام'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  const _ReadyCard({required this.shipment});

  final Shipment shipment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => context.push(TransportRoutes.shipment(shipment.id)),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.09),
          child: Icon(
            Icons.inventory_2_outlined,
            size: 19,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          shipment.customer,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${shipment.id} · ${shipment.from} ← ${shipment.to} · '
          '${formatNumber(shipment.weight, decimals: 1)} كجم',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: StatusChip(status: shipment.status, compact: true),
      ),
    );
  }
}
