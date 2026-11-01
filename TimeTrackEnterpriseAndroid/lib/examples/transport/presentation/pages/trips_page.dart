import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../transport_routes.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/shipment.dart';
import '../../domain/entities/transport_meta.dart';
import '../../domain/entities/trip.dart';
import '../providers/transport_providers.dart';
import '../widgets/transport_format.dart';
import '../widgets/transport_widgets.dart';

class TripsPage extends ConsumerStatefulWidget {
  const TripsPage({super.key});

  @override
  ConsumerState<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends ConsumerState<TripsPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _status = '';
  bool _onlyOpen = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripsProvider);
    final shipments =
        ref.watch(shipmentsProvider).valueOrNull?.value ?? const <Shipment>[];
    final meta =
        ref.watch(transportMetaProvider).valueOrNull ?? TransportMeta.fallback;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(TransportRoutes.tripNew),
        icon: const Icon(Icons.add_road_rounded),
        label: const Text('رحلة جديدة'),
      ),
      body: Column(
        children: <Widget>[
          PageHero(
            title: 'إدارة الرحلات',
            subtitle: 'ربط الشحنات وتحميلها حتى إغلاق الرحلة',
            actions: <Widget>[
              HeroIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'تحديث',
                onTap: () {
                  ref.invalidate(tripsProvider);
                  ref.invalidate(shipmentsProvider);
                },
              ),
            ],
          ),
          Expanded(
            child: trips.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorState(
                  error: error,
                  onRetry: () => ref.invalidate(tripsProvider),
                ),
              ),
              data: (data) {
                final all = data.value;
                final filtered = _filter(all);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(tripsProvider);
                    ref.invalidate(shipmentsProvider);
                    await ref.read(tripsProvider.future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: <Widget>[
                      if (data.fromCache) ...<Widget>[
                        const CachedBanner(),
                        const SizedBox(height: 12),
                      ],
                      _TripsSummary(trips: all, shipments: shipments),
                      const SizedBox(height: 14),
                      SearchBox(
                        controller: _search,
                        hint: 'ابحث باسم الرحلة أو المركبة أو السائق...',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            ChoiceChip(
                              label: const Text('الكل'),
                              selected: _status.isEmpty && !_onlyOpen,
                              onSelected: (_) => setState(() {
                                _status = '';
                                _onlyOpen = false;
                              }),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('النشطة'),
                              selected: _onlyOpen,
                              onSelected: (_) => setState(() {
                                _onlyOpen = !_onlyOpen;
                                _status = '';
                              }),
                            ),
                            ...meta.tripFlow.map(
                              (status) => Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(start: 8),
                                child: ChoiceChip(
                                  label: Text(status),
                                  selected: _status == status,
                                  onSelected: (_) => setState(() {
                                    _status = _status == status ? '' : status;
                                    _onlyOpen = false;
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
                          icon: Icons.route_outlined,
                          title: 'لا توجد رحلات',
                          subtitle: all.isEmpty
                              ? 'أنشئ رحلة ثم اربط بها الشحنات الجاهزة وأكد التحميل.'
                              : 'لا توجد رحلات مطابقة للبحث أو الفلتر.',
                          action: FilledButton.icon(
                            onPressed: () =>
                                context.push(TransportRoutes.tripNew),
                            icon: const Icon(Icons.add_road_rounded, size: 18),
                            label: const Text('إنشاء رحلة'),
                          ),
                        )
                      else
                        ...filtered.map(
                          (trip) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TripCard(
                              trip: trip,
                              shipments: shipments,
                              onOpen: () =>
                                  context.push(TransportRoutes.trip(trip.id)),
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

  List<Trip> _filter(List<Trip> all) {
    final query = _query.trim().toLowerCase();
    final list = all.where((trip) {
      if (_onlyOpen && (trip.closed || trip.status == 'وصلت للوجهة')) {
        return false;
      }
      if (_status.isNotEmpty && trip.status != _status) return false;
      if (query.isEmpty) return true;
      return '${trip.id} ${trip.name} ${trip.from} ${trip.to} '
              '${trip.vehicle} ${trip.driver}'
          .toLowerCase()
          .contains(query);
    }).toList();

    list.sort((a, b) {
      final left = a.dates.plan;
      final right = b.dates.plan;
      if (left == null && right == null) return b.id.compareTo(a.id);
      if (left == null) return 1;
      if (right == null) return -1;
      return right.compareTo(left);
    });
    return list;
  }
}

double tripLoadedWeight(Trip trip, List<Shipment> shipments) {
  return shipments
      .where(
        (shipment) => shipment.tripId == trip.id && shipment.isLoaded,
      )
      .fold<double>(0, (sum, shipment) => sum + shipment.weight);
}

List<Shipment> tripLinkedShipments(Trip trip, List<Shipment> shipments) {
  return shipments
      .where((shipment) => shipment.tripId == trip.id)
      .toList(growable: false);
}

class _TripsSummary extends StatelessWidget {
  const _TripsSummary({required this.trips, required this.shipments});

  final List<Trip> trips;
  final List<Shipment> shipments;

  @override
  Widget build(BuildContext context) {
    final planned =
        trips.where((trip) => trip.status == 'مخططة' && !trip.closed).length;
    final moving = trips
        .where(
          (trip) =>
              !trip.closed &&
              (trip.status == 'تم التحميل' || trip.status == 'في الطريق'),
        )
        .length;
    final used = trips.fold<double>(
      0,
      (sum, trip) => sum + tripLoadedWeight(trip, shipments),
    );
    final capacity = trips.fold<double>(
      0,
      (sum, trip) => sum + trip.capacityKg,
    );
    final utilization =
        capacity <= 0 ? 0 : (used / capacity * 100).clamp(0, 999).toDouble();

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
                label: 'رحلات مخططة',
                value: formatNumber(planned),
                icon: Icons.event_note_rounded,
                tone: const Color(0xFF6B7280),
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'رحلات نشطة',
                value: formatNumber(moving),
                icon: Icons.local_shipping_rounded,
                tone: const Color(0xFF1E5FA8),
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'استغلال السعة',
                value: '${formatNumber(utilization)}%',
                icon: Icons.speed_rounded,
                tone: const Color(0xFFB3741A),
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'إجمالي الرحلات',
                value: formatNumber(trips.length),
                icon: Icons.route_rounded,
                tone: const Color(0xFF17795E),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.shipments,
    required this.onOpen,
  });

  final Trip trip;
  final List<Shipment> shipments;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linked = tripLinkedShipments(trip, shipments);
    final used = tripLoadedWeight(trip, shipments);
    final ratio =
        trip.capacityKg <= 0 ? 0.0 : (used / trip.capacityKg).clamp(0, 1);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.route_rounded,
                      size: 19,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          trip.name.isEmpty ? trip.id : trip.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${trip.from} ← ${trip.to} · ${trip.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    status: trip.closed ? 'مقفلة' : trip.status,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trip.vehicle.isEmpty ? 'بدون مركبة' : trip.vehicle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Icon(
                    Icons.badge_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      trip.driver.isEmpty ? 'بدون سائق' : trip.driver,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: ratio.toDouble(),
                  minHeight: 7,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: ratio >= 0.95
                      ? const Color(0xFFB3741A)
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Text(
                    '${formatNumber(used)} / ${formatNumber(trip.capacityKg)} كجم',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${linked.length} شحنة · متبقي '
                    '${formatNumber((trip.capacityKg - used).clamp(0, double.infinity))} كجم',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
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
                    formatDateTime(trip.dates.plan),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'فتح مركز التحكم',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
