import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/i18n/app_locale.dart';
import '../../../../app/i18n/app_strings.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/example_item.dart';
import '../../presentation/providers/example_items_providers.dart';

class ExampleItemsPage extends ConsumerStatefulWidget {
  const ExampleItemsPage({super.key});

  @override
  ConsumerState<ExampleItemsPage> createState() => _ExampleItemsPageState();
}

class _ExampleItemsPageState extends ConsumerState<ExampleItemsPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final items = ref.watch(exampleItemsProvider(_query));

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.exampleRecords),
        actions: <Widget>[
          IconButton(
            tooltip: strings.languageSwitch,
            onPressed: () => toggleAppLocale(ref),
            icon: const Icon(Icons.translate_rounded),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: strings.exampleRecords,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: strings.cancel,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _refresh(_query),
                  child: items.when(
                    loading: () => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: <Widget>[
                        const SizedBox(height: 120),
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 16),
                        Center(child: Text(strings.loading)),
                      ],
                    ),
                    error: (error, _) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      children: <Widget>[
                        const SizedBox(height: 70),
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 40,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        Center(child: Text(strings.loadFailed)),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            '$error',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => _refresh(_query),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(strings.retry),
                          ),
                        ),
                      ],
                    ),
                    data: (records) => records.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            children: <Widget>[
                              const SizedBox(height: 90),
                              Icon(
                                Icons.list_alt_outlined,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Center(child: Text(strings.noItems)),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                            itemCount: records.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) => _ExampleItemTile(
                              item: records[index],
                              strings: strings,
                              onEdit: () => _openForm(records[index]),
                              onDelete: () => _delete(records[index]),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: Text(strings.addItem),
      ),
    );
  }

  Future<void> _refresh(String query) async {
    final provider = exampleItemsProvider(query);
    ref.invalidate(provider);
    try {
      await ref.read(provider.future);
    } catch (_) {
      // The AsyncValue below renders the failure and offers a retry action.
    }
  }

  Future<void> _openForm([ExampleItem? item]) async {
    final strings = AppStrings.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _ExampleItemFormDialog(
        initial: item,
        strings: strings,
        onSave: (draft) async {
          final repository = ref.read(exampleItemRepositoryProvider);
          if (item == null) {
            await repository.create(
              name: draft.name,
              code: draft.code,
              description: draft.description,
              quantity: draft.quantity,
            );
          } else {
            await repository.update(
              item.id,
              name: draft.name,
              code: draft.code,
              description: draft.description,
              quantity: draft.quantity,
            );
          }
          ref.invalidate(exampleItemsProvider(_query));
        },
      ),
    );
  }

  Future<void> _delete(ExampleItem item) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteItem),
        content: Text(strings.deletePrompt),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.deleteItem),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(exampleItemRepositoryProvider).delete(item.id);
      ref.invalidate(exampleItemsProvider(_query));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.loadFailed}: $error')),
      );
    }
  }
}

class _ExampleItemTile extends StatelessWidget {
  const _ExampleItemTile({
    required this.item,
    required this.strings,
    required this.onEdit,
    required this.onDelete,
  });

  final ExampleItem item;
  final AppStrings strings;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const IconBadge(
          icon: Icons.dataset_outlined,
          tone: AppColors.info,
          size: 42,
        ),
        title: Text(item.name),
        subtitle: Text('${item.code} · ${strings.quantity}: ${item.quantity}'),
        isThreeLine: item.description.isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'edit',
              child: Text(strings.editItem),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Text(strings.deleteItem),
            ),
          ],
        ),
        subtitleTextStyle: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _ExampleItemFormDialog extends StatefulWidget {
  const _ExampleItemFormDialog({
    required this.initial,
    required this.strings,
    required this.onSave,
  });

  final ExampleItem? initial;
  final AppStrings strings;
  final Future<void> Function(_ExampleItemDraft draft) onSave;

  @override
  State<_ExampleItemFormDialog> createState() => _ExampleItemFormDialogState();
}

class _ExampleItemFormDialogState extends State<_ExampleItemFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final TextEditingController _codeController =
      TextEditingController(text: widget.initial?.code ?? '');
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late final TextEditingController _quantityController =
      TextEditingController(text: '${widget.initial?.quantity ?? 0}');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return AlertDialog(
      title: Text(widget.initial == null ? strings.addItem : strings.editItem),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_error != null) ...<Widget>[
                  AppBanner(
                    message: _error!,
                    tone: Theme.of(context).colorScheme.error,
                    icon: Icons.error_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _nameController,
                  enabled: !_saving,
                  decoration: InputDecoration(labelText: strings.name),
                  validator: _validateRequired,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(labelText: strings.code),
                  validator: _validateRequired,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_saving,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: strings.description),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _quantityController,
                  enabled: !_saving,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: strings.quantity),
                  validator: (value) {
                    final quantity = int.tryParse(value?.trim() ?? '');
                    if (quantity == null || quantity < 0) {
                      return strings.quantityInvalid;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(strings.save),
        ),
      ],
    );
  }

  String? _validateRequired(String? value) =>
      value == null || value.trim().isEmpty
          ? widget.strings.fieldRequired
          : null;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSave(
        _ExampleItemDraft(
          name: _nameController.text.trim(),
          code: _codeController.text.trim(),
          description: _descriptionController.text.trim(),
          quantity: int.parse(_quantityController.text.trim()),
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ExampleItemDraft {
  const _ExampleItemDraft({
    required this.name,
    required this.code,
    required this.description,
    required this.quantity,
  });

  final String name;
  final String code;
  final String description;
  final int quantity;
}
