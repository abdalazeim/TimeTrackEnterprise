import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/goods_type.dart';
import '../../domain/entities/reference_entities.dart';
import '../../domain/entities/shipment.dart';
import '../../domain/entities/transport_meta.dart';
import '../../domain/entities/value_readers.dart';
import '../providers/transport_providers.dart';
import '../widgets/shipment_actions.dart';
import '../widgets/transport_format.dart';
import '../widgets/transport_widgets.dart';

/// يحمّل الشحنة من القائمة ثم يفتح نموذج التعديل.
class ShipmentEditLoader extends ConsumerWidget {
  const ShipmentEditLoader({required this.shipmentId, super.key});

  final String shipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shipments = ref.watch(shipmentsProvider);
    return shipments.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('تعديل الشحنة')),
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
            appBar: AppBar(title: const Text('تعديل الشحنة')),
            body: const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'الشحنة غير موجودة',
              subtitle: 'ربما حُذفت أو تغيّر رقمها. ارجع إلى القائمة وحدّثها.',
            ),
          );
        }
        return ShipmentFormPage(shipment: shipment);
      },
    );
  }
}

class ShipmentFormPage extends ConsumerStatefulWidget {
  const ShipmentFormPage({super.key, this.shipment});

  final Shipment? shipment;

  @override
  ConsumerState<ShipmentFormPage> createState() => _ShipmentFormPageState();
}

class _ShipmentFormPageState extends ConsumerState<ShipmentFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _customer;
  late final TextEditingController _consignee;
  late final TextEditingController _consigneePhone;
  late final TextEditingController _consigneeNotes;
  late final TextEditingController _shipperPhone;
  late final TextEditingController _shipperNotes;
  late final TextEditingController _distance;
  late final TextEditingController _advance;
  late final TextEditingController _notes;

  late List<_ItemDraft> _items;
  final Set<int> _services = <int>{};
  late String _from;
  late String _to;
  late String _method;
  bool _urgent = false;
  bool _busy = false;

  Shipment? get _editing => widget.shipment;

  bool get _isDraft => _editing?.isDraft ?? false;

  @override
  void initState() {
    super.initState();
    final meta =
        ref.read(transportMetaProvider).valueOrNull ?? TransportMeta.fallback;
    final shipment = widget.shipment;

    _customer = TextEditingController(text: shipment?.customer ?? '');
    _consignee = TextEditingController(text: shipment?.consignee.name ?? '');
    _consigneePhone =
        TextEditingController(text: shipment?.consignee.phone ?? '');
    _consigneeNotes =
        TextEditingController(text: shipment?.consignee.notes ?? '');
    _shipperPhone = TextEditingController(text: shipment?.shipper.phone ?? '');
    _shipperNotes = TextEditingController(text: shipment?.shipper.notes ?? '');
    _distance = TextEditingController(
      text: shipment == null || shipment.distance == 0
          ? ''
          : formatNumber(shipment.distance, decimals: 1),
    );
    _advance = TextEditingController(
      text: shipment == null ? '' : formatNumber(shipment.paid),
    );
    _notes = TextEditingController(text: shipment?.notes ?? '');

    _from =
        shipment?.from.isNotEmpty == true ? shipment!.from : meta.cities.first;
    _to = shipment?.to.isNotEmpty == true
        ? shipment!.to
        : meta.cities.length > 1
            ? meta.cities[1]
            : meta.cities.first;
    _method = shipment?.method ?? meta.methods.first;
    _urgent = shipment?.urgent ?? false;

    for (final index in shipment?.services ?? const <int>[]) {
      if (index >= 0 && index < meta.services.length) _services.add(index);
    }

    if (shipment != null && shipment.items.isNotEmpty) {
      _items = shipment.items
          .map(
            (item) => _ItemDraft(
              goods: item.goods,
              quantity: item.qty,
              unit: item.unit.isEmpty ? meta.units.first : item.unit,
              weight: item.weight,
              volume: item.volume,
              discount: item.discount,
              note: item.note ?? '',
            ),
          )
          .toList();
    } else {
      _items = <_ItemDraft>[
        _ItemDraft(unit: meta.units.first),
      ];
    }
  }

  @override
  void dispose() {
    _customer.dispose();
    _consignee.dispose();
    _consigneePhone.dispose();
    _consigneeNotes.dispose();
    _shipperPhone.dispose();
    _shipperNotes.dispose();
    _distance.dispose();
    _advance.dispose();
    _notes.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta =
        ref.watch(transportMetaProvider).valueOrNull ?? TransportMeta.fallback;
    final customers =
        ref.watch(customersProvider).valueOrNull?.value ?? const <Customer>[];
    final goods =
        ref.watch(goodsProvider).valueOrNull?.value ?? const <GoodsType>[];
    final routes =
        ref.watch(routesProvider).valueOrNull?.value ?? const <RouteInfo>[];

    final goodsNames = goods
        .map((item) => item.name)
        .where((name) => name.isNotEmpty)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing == null ? 'استلام بضائع' : 'تعديل الشحنة'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            if (_editing != null)
              CachedBanner(
                message:
                    'تعديل السجل ${_editing!.id} — الحالة الحالية: ${_editing!.status}',
              ),
            if (_editing != null) const SizedBox(height: 12),
            SectionCard(
              title: 'المرسل والمستلم',
              subtitle: 'اسم العميل، جهة التسليم، هواتف التواصل والملاحظات',
              icon: Icons.people_alt_outlined,
              child: Column(
                children: <Widget>[
                  _SuggestionField(
                    controller: _customer,
                    label: 'العميل / المرسل *',
                    hint: 'اختر عميلًا أو اكتب اسمًا جديدًا',
                    suggestions: customers.map((c) => c.name).toList(),
                    onChanged: (_) => setState(() {}),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'أدخل اسم العميل أو المرسل'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _consignee,
                    decoration: const InputDecoration(
                      labelText: 'المرسل إليه / المستلم *',
                      hintText: 'اسم المستلم',
                      prefixIcon: Icon(Icons.person_pin_circle_outlined),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'أدخل اسم المرسل إليه'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _shipperPhone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'هاتف المرسل',
                            hintText: '09xxxxxxxx',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _consigneePhone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'هاتف المستلم',
                            hintText: '09xxxxxxxx',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _consigneeNotes,
                    maxLines: 2,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات المستلم',
                      hintText: 'نقطة الإيصال أو أي تفاصيل للتسليم',
                    ),
                  ),
                  TextFormField(
                    controller: _shipperNotes,
                    maxLines: 2,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات المرسل',
                      hintText: 'تفاصيل إضافية عن المرسل أو الشاحن',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'المسار',
              subtitle: 'مدينة الشحن والوجهة والمسافة المحسوبة من المسارات',
              icon: Icons.route_rounded,
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _from,
                          decoration: const InputDecoration(labelText: 'من'),
                          items: _cityItems(meta, _from),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _from = value;
                              _syncDistance(routes);
                            });
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
                            if (value == null) return;
                            setState(() {
                              _to = value;
                              _syncDistance(routes);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _distance,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المسافة (كم)',
                      hintText: 'تُملأ تلقائيًا من جدول المسارات',
                      prefixIcon: Icon(Icons.straighten_rounded),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'بنود البضاعة',
              subtitle:
                  'يمكن إضافة عدة بنود ويُجمع الوزن والحجم والخصم تلقائيًا',
              icon: Icons.inventory_2_outlined,
              trailing: TextButton.icon(
                onPressed: () => setState(
                  () => _items.add(_ItemDraft(unit: meta.units.first)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('بند'),
              ),
              child: Column(
                children: <Widget>[
                  for (var index = 0; index < _items.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _itemCard(index, meta, goodsNames),
                    ),
                  _TotalsRow(
                    weight: _totalWeight,
                    volume: _totalVolume,
                    discount: _totalDiscount,
                    quantity: _totalQuantity,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'الخدمات الإضافية',
              subtitle: 'تُضاف قيمتها إلى أجرة الشحنة',
              icon: Icons.design_services_outlined,
              child: Column(
                children: <Widget>[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (var index = 0; index < meta.services.length; index++)
                        FilterChip(
                          label: Text(
                            '${meta.services[index].name} · '
                            '${formatMoney(meta.services[index].price)}',
                          ),
                          selected: _services.contains(index),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _services.add(index);
                            } else {
                              _services.remove(index);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _urgent,
                    onChanged: (value) => setState(() => _urgent = value),
                    title: const Text('شحنة مستعجلة'),
                    subtitle: const Text('أولوية في التحميل والانطلاق'),
                    secondary: const Icon(Icons.priority_high_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'الدفع والملاحظات',
              subtitle: 'طريقة الدفع والدفعة الأولى وتفاصيل الشحنة',
              icon: Icons.payments_outlined,
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _method,
                          decoration:
                              const InputDecoration(labelText: 'طريقة الدفع'),
                          items: _textItems(meta.methods, _method),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _method = value);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _advance,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'دفعة أولى',
                            hintText: '0',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات الشحنة',
                      hintText: 'تفاصيل إضافية عن الشحنة...',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _BusyNote(busy: _busy),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: <Widget>[
            if (_editing == null || _isDraft)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _save(receive: false),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('حفظ كمسودة'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            if (_editing == null || _isDraft) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _save(receive: true),
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 19),
                label: Text(
                  _isDraft
                      ? 'استلام وتوليد بوليصة'
                      : _editing == null
                          ? 'استلام وتوليد بوليصة'
                          : 'حفظ التعديلات',
                ),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(int index, TransportMeta meta, List<String> goodsNames) {
    final item = _items[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
                alpha: 0.6,
              ),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'البند ${index + 1}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'حذف البند',
                onPressed: _items.length == 1
                    ? null
                    : () => setState(() {
                          final removed = _items.removeAt(index);
                          removed.dispose();
                        }),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
          _SuggestionField(
            controller: item.goods,
            label: 'نوع البضاعة',
            hint: 'مثال: كرتون أجهزة',
            suggestions: goodsNames,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: item.quantity,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الكمية'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: item.unit,
                  decoration: const InputDecoration(labelText: 'الوحدة'),
                  items: _textItems(meta.units, item.unit),
                  onChanged: (value) {
                    if (value != null) setState(() => item.unit = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TextFormField(
                  controller: item.weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الوزن كجم'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: item.volume,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الحجم م³'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: item.discount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'خصم د.ل'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: item.note,
            decoration: const InputDecoration(
              labelText: 'ملاحظة البند',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  double get _totalWeight => _items.fold<double>(
        0,
        (sum, item) => sum + (parseInputNumber(item.weight.text) ?? 0),
      );

  double get _totalVolume => _items.fold<double>(
        0,
        (sum, item) => sum + (parseInputNumber(item.volume.text) ?? 0),
      );

  double get _totalDiscount => _items.fold<double>(
        0,
        (sum, item) => sum + (parseInputNumber(item.discount.text) ?? 0),
      );

  double get _totalQuantity => _items.fold<double>(
        0,
        (sum, item) => sum + (parseInputNumber(item.quantity.text) ?? 1),
      );

  String get _goodsSummary {
    final names = _items
        .map((item) => item.goods.text.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    if (names.isEmpty) return 'عام';
    if (names.length == 1) return names.first;
    return 'بضائع متنوعة';
  }

  String get _unitSummary {
    final units = _items.map((item) => item.unit).toSet();
    if (units.isEmpty) return '';
    if (units.length == 1) return units.first;
    return 'وحدة';
  }

  void _syncDistance(List<RouteInfo> routes) {
    for (final route in routes) {
      if (route.matches(_from, _to) && route.distanceKm > 0) {
        _distance.text = formatNumber(route.distanceKm, decimals: 1);
        return;
      }
    }
  }

  Future<void> _save({required bool receive}) async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_from == _to) {
      showErrorSnack(
        context,
        StateError('مدينة الشحن والوجهة متطابقتان.'),
      );
      return;
    }

    final items = _items
        .map(
      (item) => <String, dynamic>{
        'goods':
            item.goods.text.trim().isEmpty ? 'عام' : item.goods.text.trim(),
        'qty': parseInputNumber(item.quantity.text) ?? 1.0,
        'unit': item.unit,
        'wt': parseInputNumber(item.weight.text) ?? 0.0,
        'vol': parseInputNumber(item.volume.text) ?? 0.0,
        'disc': parseInputNumber(item.discount.text) ?? 0.0,
        'note': item.note.text.trim(),
      },
    )
        .where((item) {
      final weight = item['wt'] as double;
      final volume = item['vol'] as double;
      return item['goods'] != 'عام' || weight > 0 || volume > 0;
    }).toList(growable: false);

    if (items.isEmpty) {
      showErrorSnack(
        context,
        StateError('أضف بندًا واحدًا على الأقل مع اسم البضاعة أو الوزن.'),
      );
      return;
    }

    final customer = _customer.text.trim();
    final consigneeName = _consignee.text.trim();

    final payload = <String, dynamic>{
      'customer': customer,
      'from': _from,
      'to': _to,
      'goods': _goodsSummary,
      'qty': _totalQuantity,
      'unit': _unitSummary,
      'wt': _totalWeight,
      'vol': _totalVolume,
      'dist': parseInputNumber(_distance.text) ?? 0,
      'consignee': <String, dynamic>{
        'name': consigneeName,
        'phone': _consigneePhone.text.trim(),
        'notes': _consigneeNotes.text.trim(),
      },
      'shipper': <String, dynamic>{
        'name': customer,
        'phone': _shipperPhone.text.trim(),
        'notes': _shipperNotes.text.trim(),
      },
      'items': items,
      'services': _services.toList()..sort(),
      'disc': _totalDiscount,
      'notes': _notes.text.trim(),
      'urgent': _urgent,
      'method': _method,
      'advance': parseInputNumber(_advance.text) ?? 0,
    };

    setState(() => _busy = true);
    try {
      final repository = ref.read(transportRepositoryProvider);

      if (_editing == null) {
        if (receive) {
          await repository.createShipment(payload);
        } else {
          await repository.saveDraft(payload);
        }
      } else {
        await repository.editShipment(_editing!.id, payload);
        if (receive && _isDraft) {
          await repository.submitDraft(_editing!.id, payload);
        }
      }

      invalidateTransportData(ref);
      if (!mounted) return;
      showSuccessSnack(
        context,
        receive
            ? _isDraft
                ? 'تم استلام الشحنة وتوليد مستنداتها'
                : 'تم حفظ تعديلات الشحنة'
            : 'حُفظت المسودة ويمكن استلامها لاحقًا',
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
    final values = <String>{...meta.cities, current};
    return values
        .map(
          (value) => DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          ),
        )
        .toList(growable: false);
  }

  static List<DropdownMenuItem<String>> _textItems(
    List<String> values,
    String current,
  ) {
    final all = <String>{...values, current};
    return all
        .map(
          (value) => DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          ),
        )
        .toList(growable: false);
  }
}

class _ItemDraft {
  _ItemDraft({
    String goods = '',
    double quantity = 1,
    this.unit = '',
    double weight = 0,
    double volume = 0,
    double discount = 0,
    String note = '',
  })  : goods = TextEditingController(text: goods),
        quantity = TextEditingController(
          text: quantity == 0 ? '' : formatNumber(quantity, decimals: 2),
        ),
        weight = TextEditingController(
          text: weight == 0 ? '' : formatNumber(weight, decimals: 2),
        ),
        volume = TextEditingController(
          text: volume == 0 ? '' : formatNumber(volume, decimals: 2),
        ),
        discount = TextEditingController(
          text: discount == 0 ? '' : formatNumber(discount, decimals: 2),
        ),
        note = TextEditingController(text: note);

  final TextEditingController goods;
  final TextEditingController quantity;
  final TextEditingController weight;
  final TextEditingController volume;
  final TextEditingController discount;
  final TextEditingController note;
  String unit;

  void dispose() {
    goods.dispose();
    quantity.dispose();
    weight.dispose();
    volume.dispose();
    discount.dispose();
    note.dispose();
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.weight,
    required this.volume,
    required this.discount,
    required this.quantity,
  });

  final double weight;
  final double volume;
  final double discount;
  final double quantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: <Widget>[
          _chip('الكمية', formatNumber(quantity, decimals: 2)),
          _chip('الوزن', '${formatNumber(weight, decimals: 2)} كجم'),
          _chip('الحجم', '${formatNumber(volume, decimals: 2)} م³'),
          _chip('الخصم', formatMoney(discount)),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _SuggestionField extends StatelessWidget {
  const _SuggestionField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.suggestions,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final List<String> suggestions;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suggestions.isEmpty
            ? null
            : IconButton(
                tooltip: 'اختيار من القائمة',
                icon: const Icon(Icons.list_rounded),
                onPressed: () async {
                  final value = await showOptionsSheet(
                    context,
                    title: label,
                    options: suggestions,
                  );
                  if (value == null) return;
                  controller.text = value;
                  onChanged?.call(value);
                },
              ),
      ),
    );
  }
}

class _BusyNote extends StatelessWidget {
  const _BusyNote({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    if (!busy) return const SizedBox.shrink();
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
    );
  }
}
