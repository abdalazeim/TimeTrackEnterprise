import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/goods_type.dart';
import '../../domain/entities/transport_meta.dart';
import '../providers/transport_providers.dart';
import '../widgets/shipment_actions.dart';
import '../widgets/transport_format.dart';
import '../widgets/transport_widgets.dart';

class GoodsPage extends ConsumerStatefulWidget {
  const GoodsPage({super.key});

  @override
  ConsumerState<GoodsPage> createState() => _GoodsPageState();
}

class _GoodsPageState extends ConsumerState<GoodsPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _category = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goods = ref.watch(goodsProvider);
    final meta =
        ref.watch(transportMetaProvider).valueOrNull ?? TransportMeta.fallback;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, meta, null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('بضاعة جديدة'),
      ),
      body: Column(
        children: <Widget>[
          PageHero(
            title: 'إدارة البضائع',
            subtitle: 'أنواع البضائع والفئات والمخازن',
            actions: <Widget>[
              HeroIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'تحديث',
                onTap: () => ref.invalidate(goodsProvider),
              ),
            ],
          ),
          Expanded(
            child: goods.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorState(
                  error: error,
                  onRetry: () => ref.invalidate(goodsProvider),
                ),
              ),
              data: (data) {
                final all = data.value;
                final categories = <String>{
                  ...meta.goodsCategories,
                  ...all.map((item) => item.category),
                }.where((item) => item.isNotEmpty).toList(growable: false);
                final filtered = _filter(all);

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(goodsProvider);
                    await ref.read(goodsProvider.future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: <Widget>[
                      if (data.fromCache) ...<Widget>[
                        const CachedBanner(),
                        const SizedBox(height: 12),
                      ],
                      _GoodsSummary(all: all),
                      const SizedBox(height: 14),
                      SearchBox(
                        controller: _search,
                        hint: 'ابحث باسم البضاعة أو المخزن...',
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            ChoiceChip(
                              label: const Text('كل الفئات'),
                              selected: _category.isEmpty,
                              onSelected: (_) => setState(() => _category = ''),
                            ),
                            ...categories.map(
                              (category) => Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(start: 8),
                                child: ChoiceChip(
                                  label: Text(category),
                                  selected: _category == category,
                                  onSelected: (_) => setState(
                                    () => _category =
                                        _category == category ? '' : category,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (filtered.isEmpty)
                        EmptyState(
                          icon: Icons.category_outlined,
                          title: 'لا توجد بضائع',
                          subtitle: all.isEmpty
                              ? 'أضف أنواع البضائع لتسريع إنشاء الشحنات لاحقًا.'
                              : 'لا توجد نتائج مطابقة للبحث أو الفئة المختارة.',
                          action: FilledButton.icon(
                            onPressed: () => _openForm(context, meta, null),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('إضافة بضاعة'),
                          ),
                        )
                      else
                        ...filtered.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _GoodsCard(
                              item: item,
                              onEdit: () => _openForm(context, meta, item),
                              onDelete: () => _delete(context, item),
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

  List<GoodsType> _filter(List<GoodsType> all) {
    final query = _query.trim().toLowerCase();
    return all.where((item) {
      if (_category.isNotEmpty && item.category != _category) return false;
      if (query.isEmpty) return true;
      return '${item.name} ${item.category} ${item.store ?? ''} '
              '${item.note ?? ''}'
          .toLowerCase()
          .contains(query);
    }).toList(growable: false);
  }

  Future<void> _openForm(
    BuildContext context,
    TransportMeta meta,
    GoodsType? item,
  ) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _GoodsForm(meta: meta, item: item),
    );
    if (saved == true && context.mounted) {
      showSuccessSnack(
        context,
        item == null ? 'تمت إضافة البضاعة' : 'تم تحديث البضاعة',
      );
    }
  }

  Future<void> _delete(BuildContext context, GoodsType item) async {
    final confirmed = await confirmAction(
      context,
      title: 'حذف البضاعة',
      message: 'سيتم حذف «${item.name}» من مرجع البضائع. '
          'الشحنات السابقة لا تتأثر.',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(transportRepositoryProvider).deleteGoods(item.id);
      ref.invalidate(goodsProvider);
      if (!context.mounted) return;
      showSuccessSnack(context, 'تم حذف البضاعة');
    } catch (error) {
      if (!context.mounted) return;
      showErrorSnack(context, error);
    }
  }
}

class _GoodsSummary extends StatelessWidget {
  const _GoodsSummary({required this.all});

  final List<GoodsType> all;

  @override
  Widget build(BuildContext context) {
    final hazardous = all.where((item) => item.hazardous).length;
    final categories = all.map((item) => item.category).toSet().length;
    final stores = all
        .map((item) => item.store)
        .whereType<String>()
        .where((store) => store.isNotEmpty)
        .toSet()
        .length;

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
                label: 'أنواع البضائع',
                value: formatNumber(all.length),
                icon: Icons.category_rounded,
                tone: const Color(0xFF1E5FA8),
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'الفئات',
                value: formatNumber(categories),
                icon: Icons.sell_outlined,
                tone: const Color(0xFF17795E),
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'مواد خطرة',
                value: formatNumber(hazardous),
                icon: Icons.warning_amber_rounded,
                tone: const Color(0xFFB3741A),
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'المخازن',
                value: formatNumber(stores),
                icon: Icons.warehouse_outlined,
                tone: const Color(0xFF6B5B95),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GoodsCard extends StatelessWidget {
  const _GoodsCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final GoodsType item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
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
                    item.hazardous
                        ? Icons.warning_amber_rounded
                        : Icons.inventory_2_outlined,
                    size: 19,
                    color: item.hazardous
                        ? const Color(0xFFB3741A)
                        : theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${item.category} · ${item.unit}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'خيارات',
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Text('تعديل'),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('حذف'),
                    ),
                  ],
                ),
              ],
            ),
            if ((item.store ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.warehouse_outlined,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.store!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if ((item.note ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                item.note!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
            if (item.hazardous) ...<Widget>[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3741A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Text(
                    'مادة خطرة — يتطلب تعاملًا خاصًا',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF8A5A12),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoodsForm extends ConsumerStatefulWidget {
  const _GoodsForm({required this.meta, this.item});

  final TransportMeta meta;
  final GoodsType? item;

  @override
  ConsumerState<_GoodsForm> createState() => _GoodsFormState();
}

class _GoodsFormState extends ConsumerState<_GoodsForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.item?.name ?? '');
  late final TextEditingController _store =
      TextEditingController(text: widget.item?.store ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.item?.note ?? '');
  late String _category =
      widget.item?.category ?? widget.meta.goodsCategories.first;
  late String _unit = widget.item?.unit ?? widget.meta.units.first;
  late bool _hazardous = widget.item?.hazardous ?? false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _store.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = <String>{
      ...widget.meta.goodsCategories,
      _category,
    }.toList(growable: false);
    final units = <String>{...widget.meta.units, _unit}.toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.item == null ? 'إضافة بضاعة' : 'تعديل بضاعة',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'اسم البضاعة *',
                  hintText: 'مثال: كرتون أجهزة',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'أدخل اسم البضاعة' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: const InputDecoration(labelText: 'الفئة'),
                      items: categories
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) setState(() => _category = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: const InputDecoration(labelText: 'الوحدة'),
                      items: units
                          .map(
                            (value) => DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) setState(() => _unit = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _store,
                decoration: const InputDecoration(
                  labelText: 'المخزن الافتراضي',
                  hintText: 'مثال: مستودع طرابلس الرئيسي',
                  prefixIcon: Icon(Icons.warehouse_outlined),
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _hazardous,
                onChanged: (value) => setState(() => _hazardous = value),
                title: const Text('مادة خطرة'),
                subtitle: const Text('تتطلب تعاملًا وتخزينًا خاصًا'),
                secondary: const Icon(Icons.warning_amber_rounded),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _note,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  hintText: 'تفاصيل التغليف أو التخزين...',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 19),
                label: const Text('حفظ البضاعة'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'cat': _category,
      'haz': _hazardous ? 1 : 0,
      'unit': _unit,
      'store': _store.text.trim(),
      'note': _note.text.trim(),
    };

    try {
      final repository = ref.read(transportRepositoryProvider);
      if (widget.item == null) {
        await repository.createGoods(payload);
      } else {
        await repository.updateGoods(widget.item!.id, payload);
      }
      ref.invalidate(goodsProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      showErrorSnack(context, error);
    }
  }
}
