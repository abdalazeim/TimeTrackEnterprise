import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/shipment.dart';
import '../../domain/entities/transport_meta.dart';
import '../providers/transport_providers.dart';
import 'transport_format.dart';

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  minimumSize: const Size(90, 42),
                )
              : FilledButton.styleFrom(minimumSize: const Size(90, 42)),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

void showErrorSnack(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(errorMessage(error)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
}

void showSuccessSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> advanceShipmentAction(
  BuildContext context,
  WidgetRef ref,
  Shipment shipment,
) async {
  try {
    await ref.read(transportRepositoryProvider).advanceShipment(shipment.id);
    invalidateTransportData(ref, goods: false);
    if (!context.mounted) return;
    showSuccessSnack(context, 'تم تحديث حالة الشحنة ${shipment.id}');
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnack(context, error);
  }
}

Future<void> submitDraftAction(
  BuildContext context,
  WidgetRef ref,
  Shipment shipment,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'استلام البضاعة',
    message:
        'سيتم تحويل المسودة ${shipment.rog ?? shipment.id} إلى شحنة مستلمة '
        'وتوليد البوليصة والفاتورة.',
    confirmLabel: 'استلام الآن',
  );
  if (!confirmed || !context.mounted) return;

  try {
    await ref.read(transportRepositoryProvider).submitDraft(shipment.id);
    invalidateTransportData(ref, goods: false);
    if (!context.mounted) return;
    showSuccessSnack(context, 'تم استلام الشحنة وتوليد مستنداتها');
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnack(context, error);
  }
}

Future<void> shipmentExceptionAction(
  BuildContext context,
  WidgetRef ref,
  Shipment shipment,
  TransportMeta meta,
) async {
  final status = await showDialog<(String, String)>(
    context: context,
    builder: (dialogContext) => _ExceptionDialog(
      shipment: shipment,
      exceptions: meta.exceptions,
    ),
  );
  if (status == null || !context.mounted) return;

  try {
    await ref.read(transportRepositoryProvider).setShipmentException(
          shipment.id,
          status: status.$1,
          note: status.$2,
        );
    invalidateTransportData(ref, goods: false);
    if (!context.mounted) return;
    showSuccessSnack(context, 'تم تطبيق الحالة الاستثنائية');
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnack(context, error);
  }
}

Future<void> deleteShipmentAction(
  BuildContext context,
  WidgetRef ref,
  Shipment shipment,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'حذف الشحنة',
    message: 'سيتم حذف السجل ${shipment.rog ?? shipment.id} نهائيًا مع سنداته '
        'وفاتورته. لا يمكن التراجع.',
    confirmLabel: 'حذف نهائي',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  try {
    await ref.read(transportRepositoryProvider).deleteShipment(shipment.id);
    invalidateTransportData(ref, goods: false);
    if (!context.mounted) return;
    showSuccessSnack(context, 'تم حذف الشحنة');
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnack(context, error);
  }
}

Future<void> unloadShipmentAction(
  BuildContext context,
  WidgetRef ref,
  Shipment shipment,
) async {
  final confirmed = await confirmAction(
    context,
    title: 'إزالة من الرحلة',
    message: 'سيتم فصل الشحنة ${shipment.id} عن الرحلة وإعادتها إلى قائمة '
        'البضائع المتاحة.',
    confirmLabel: 'إزالة',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;

  try {
    await ref.read(transportRepositoryProvider).unloadShipment(shipment.id);
    invalidateTransportData(ref, goods: false);
    if (!context.mounted) return;
    showSuccessSnack(context, 'تمت إزالة الشحنة من الرحلة');
  } catch (error) {
    if (!context.mounted) return;
    showErrorSnack(context, error);
  }
}

class _ExceptionDialog extends StatefulWidget {
  const _ExceptionDialog({
    required this.shipment,
    required this.exceptions,
  });

  final Shipment shipment;
  final List<String> exceptions;

  @override
  State<_ExceptionDialog> createState() => _ExceptionDialogState();
}

class _ExceptionDialogState extends State<_ExceptionDialog> {
  late String _status = widget.exceptions.first;
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('معالجة استثنائية — ${widget.shipment.id}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'الحالة'),
              items: widget.exceptions
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'سبب التحويل',
                hintText: 'مثال: بطلب العميل، تأخر وصول...',
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            (_status, _note.text.trim()),
          ),
          child: const Text('تطبيق الحالة'),
        ),
      ],
    );
  }
}
