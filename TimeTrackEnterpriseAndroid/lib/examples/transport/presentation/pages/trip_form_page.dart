import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/reference_entities.dart';
import '../../domain/entities/transport_meta.dart';
import '../../domain/entities/trip.dart';
import '../../domain/entities/value_readers.dart';
import '../providers/transport_providers.dart';
import '../widgets/shipment_actions.dart';
import '../widgets/transport_format.dart';
import '../widgets/transport_widgets.dart';

/// يحمّل الرحلة من القائمة ثم يفتح نموذج التعديل.
class TripEditLoader extends ConsumerWidget {
  const TripEditLoader({required this.tripId, super.key});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider);
    return trips.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('تعديل الرحلة')),
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
            appBar: AppBar(title: const Text('تعديل الرحلة')),
            body: const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'الرحلة غير موجودة',
              subtitle: 'ربما حُذفت أو تغيّر رقمها.',
            ),
          );
        }
        return TripFormPage(trip: trip);
      },
    );
  }
}

class TripFormPage extends ConsumerStatefulWidget {
  const TripFormPage({super.key, this.trip});

  final Trip? trip;

  @override
  ConsumerState<TripFormPage> createState() => _TripFormPageState();
}

class _TripFormPageState extends ConsumerState<TripFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.trip?.name ?? '');
  late final TextEditingController _capacity = TextEditingController(
    text: widget.trip == null ? '8000' : formatNumber(widget.trip!.capacityKg),
  );
  late final TextEditingController _stops = TextEditingController(
    text: widget.trip?.stops.join('، ') ?? '',
  );
  late final TextEditingController _note =
      TextEditingController(text: widget.trip?.note ?? '');
  late String _from;
  late String _to;
  late String _vehicle;
  late String _driver;
  late DateTime _plan;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final meta =
        ref.read(transportMetaProvider).valueOrNull ?? TransportMeta.fallback;
    final vehicles =
        ref.read(vehiclesProvider).valueOrNull?.value ?? const <Vehicle>[];
    final drivers =
        ref.read(driversProvider).valueOrNull?.value ?? const <Driver>[];
    final trip = widget.trip;

    _from = trip?.from.isNotEmpty == true ? trip!.from : meta.cities.first;
    _to = trip?.to.isNotEmpty == true
        ? trip!.to
        : meta.cities.length > 1
            ? meta.cities[1]
            : meta.cities.first;
    _vehicle = trip?.vehicle ?? '';
    _driver = trip?.driver ?? '';
    if (_vehicle.isEmpty && vehicles.isNotEmpty) {
      _vehicle = vehicles.first.name;
    }
    if (_driver.isEmpty && drivers.isNotEmpty) {
      _driver = drivers.first.name;
    }
    _plan = trip?.dates.plan ?? DateTime.now();
  }

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    _stops.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta =
        ref.watch(transportMetaProvider).valueOrNull ?? TransportMeta.fallback;
    final vehicles =
        ref.watch(vehiclesProvider).valueOrNull?.value ?? const <Vehicle>[];
    final drivers =
        ref.watch(driversProvider).valueOrNull?.value ?? const <Driver>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip == null ? 'رحلة جديدة' : 'تعديل الرحلة'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            if (widget.trip != null)
              CachedBanner(
                message: 'تعديل الرحلة ${widget.trip!.id} — الحالة: '
                    '${widget.trip!.closed ? 'مقفلة' : widget.trip!.status}',
              ),
            if (widget.trip != null) const SizedBox(height: 12),
            SectionCard(
              title: 'بيانات الرحلة',
              subtitle: 'الاسم والمسار والمركبة والسائق والسعة',
              icon: Icons.route_rounded,
              child: Column(
                children: <Widget>[
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'اسم الرحلة *',
                      hintText: 'مثال: رحلة طرابلس — بنغازي',
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'اكتب اسم الرحلة' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _from,
                          decoration: const InputDecoration(labelText: 'من'),
                          items: _cityItems(meta, _from),
                          onChanged: (value) {
                            if (value != null) setState(() => _from = value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _to,
                          decoration: const InputDecoration(labelText: 'إلى'),
                          items: _cityItems(meta, _to),
                          onChanged: (value) {
                            if (value != null) setState(() => _to = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _vehicle.isEmpty ? null : _vehicle,
                    decoration: const InputDecoration(
                      labelText: 'المركبة',
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                    items: _vehicleItems(vehicles, _vehicle),
                    onChanged: (value) =>
                        setState(() => _vehicle = value ?? ''),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _driver.isEmpty ? null : _driver,
                    decoration: const InputDecoration(
                      labelText: 'السائق',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: _driverItems(drivers, _driver),
                    onChanged: (value) => setState(() => _driver = value ?? ''),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _capacity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'السعة الكلية (كجم)',
                      prefixIcon: Icon(Icons.scale_outlined),
                    ),
                    validator: (value) {
                      final parsed = parseInputNumber(value ?? '');
                      if (parsed == null || parsed <= 0) {
                        return 'أدخل سعة أكبر من صفر';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _pickPlan,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ التخطيط',
                        prefixIcon: Icon(Icons.event_rounded),
                      ),
                      child: Text(formatDateTime(_plan)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _stops,
                    decoration: const InputDecoration(
                      labelText: 'المحطات',
                      hintText: 'طرابلس، الخمس، مصراتة',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات',
                      hintText: 'تفاصيل الرحلة...',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .secondaryContainer
                  .withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.info_outline_rounded, size: 19),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'بعد إنشاء الرحلة يمكنك ربط الشحنات المستلمة من مركز '
                        'تحكم الرحلة، ثم تأكيد التحميل وتغيير الحالة حتى الوصول.',
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
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _busy ? null : _save,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 19),
          label: Text(
            widget.trip == null ? 'إنشاء الرحلة' : 'حفظ التعديلات',
          ),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
      ),
    );
  }

  Future<void> _pickPlan() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _plan,
      firstDate: DateTime(_plan.year - 1),
      lastDate: DateTime(_plan.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_plan),
    );
    if (!mounted) return;
    setState(() {
      _plan = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _plan.hour,
        time?.minute ?? _plan.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_from == _to) {
      showErrorSnack(
        context,
        StateError('مدينة الانطلاق والوجهة متطابقتان.'),
      );
      return;
    }

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'from': _from,
      'to': _to,
      'vehicle': _vehicle,
      'driver': _driver,
      'capKg': parseInputNumber(_capacity.text) ?? 8000,
      'plan': formatPlan(_plan),
      'stops': _stops.text.trim(),
      'note': _note.text.trim(),
    };

    setState(() => _busy = true);
    try {
      final repository = ref.read(transportRepositoryProvider);
      if (widget.trip == null) {
        await repository.createTrip(payload);
      } else {
        await repository.updateTrip(widget.trip!.id, payload);
      }
      ref.invalidate(tripsProvider);
      ref.invalidate(shipmentsProvider);
      ref.invalidate(vehiclesProvider);
      ref.invalidate(driversProvider);
      if (!mounted) return;
      showSuccessSnack(
        context,
        widget.trip == null ? 'تم إنشاء الرحلة' : 'تم حفظ تعديلات الرحلة',
      );
      context.pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnack(context, error);
    }
  }

  static List<DropdownMenuItem<String>> _cityItems(
    TransportMeta meta,
    String current,
  ) {
    return <String>{...meta.cities, current}
        .map(
          (value) => DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          ),
        )
        .toList(growable: false);
  }

  static List<DropdownMenuItem<String>> _vehicleItems(
    List<Vehicle> vehicles,
    String current,
  ) {
    final byName = <String, Vehicle>{
      for (final vehicle in vehicles) vehicle.name: vehicle,
    };
    if (current.isNotEmpty) {
      byName.putIfAbsent(current, () => Vehicle.empty(current));
    }
    return byName.values
        .map(
          (vehicle) => DropdownMenuItem<String>(
            value: vehicle.name,
            child: Text(
              vehicle.plate.isEmpty
                  ? vehicle.name
                  : '${vehicle.name} · ${vehicle.plate}',
            ),
          ),
        )
        .toList(growable: false);
  }

  static List<DropdownMenuItem<String>> _driverItems(
    List<Driver> drivers,
    String current,
  ) {
    final byName = <String, Driver>{
      for (final driver in drivers) driver.name: driver,
    };
    if (current.isNotEmpty) {
      byName.putIfAbsent(current, () => Driver.empty(current));
    }
    return byName.values
        .map(
          (driver) => DropdownMenuItem<String>(
            value: driver.name,
            child: Text(
              driver.phone.isEmpty
                  ? driver.name
                  : '${driver.name} · ${driver.phone}',
            ),
          ),
        )
        .toList(growable: false);
  }
}
