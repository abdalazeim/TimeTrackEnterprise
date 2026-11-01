import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/i18n/app_strings.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/portal_snapshot.dart';
import '../providers/gateway_provider.dart';

class GatewayPortalPage extends ConsumerStatefulWidget {
  const GatewayPortalPage({super.key});

  @override
  ConsumerState<GatewayPortalPage> createState() => _GatewayPortalPageState();
}

class _GatewayPortalPageState extends ConsumerState<GatewayPortalPage> {
  final TextEditingController _server = TextEditingController();
  final TextEditingController _code = TextEditingController();
  String _mode = 'staff';
  String _role = 'employee';
  String? _selectedChildId;
  Map<String, Object?>? _staffData;
  Map<String, Object?>? _parentData;
  Map<String, Object?>? _notificationData;

  @override
  void dispose() {
    _server.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final controller = ref.read(gatewayProvider.notifier);
    final ok = _mode == 'staff'
        ? await controller.loginStaff(
            server: _server.text,
            role: _role,
            code: _code.text,
          )
        : await controller.loginParent(server: _server.text, code: _code.text);
    if (!mounted) return;
    final strings = AppStrings.of(context);
    final gateway = ref.read(gatewayProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? (_mode == 'staff'
                ? strings.staffSignedIn
                : strings.parentSignedIn)
            : gateway.error ?? strings.unknownError),
      ),
    );
    if (ok) {
      _code.clear();
      await _loadPortalData();
    }
  }

  Future<void> _loadPortalData() async {
    final controller = ref.read(gatewayProvider.notifier);
    final portal = ref.read(gatewayProvider).portal;
    if (portal.isStaff) {
      final result = await controller.staffDashboard();
      if (mounted) setState(() => _staffData = result?.data);
      return;
    }
    if (!portal.isParent || portal.children.isEmpty) return;
    final child = portal.children.firstWhere(
      (item) => item.id == _selectedChildId,
      orElse: () => portal.children.first,
    );
    final data = await controller.parentData(child);
    final notifications = await controller.parentNotifications(child);
    if (mounted) {
      setState(() {
        _selectedChildId = child.id;
        _parentData = data?.data;
        _notificationData = notifications?.data;
      });
    }
  }

  Future<void> _markNotificationsRead(PortalChild child) async {
    final rows = _notificationRows;
    final ids = rows
        .map((row) => row['id'])
        .whereType<num>()
        .map((id) => id.toInt())
        .toList(growable: false);
    await ref.read(gatewayProvider.notifier).markNotificationsRead(child, ids);
    await _loadPortalData();
  }

  List<Map<String, Object?>> get _notificationRows {
    final raw = _notificationData?['notifications'];
    if (raw is! List) return const <Map<String, Object?>>[];
    return raw
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList(growable: false);
  }

  String _formatData(Map<String, Object?>? data, AppStrings strings) {
    if (data == null || data.isEmpty) return strings.noPortalData;
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  Future<void> _removeChild(PortalChild child) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.removeChild),
        content: Text(strings.removeChildPrompt),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.removeChild)),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(gatewayProvider.notifier).removeChild(child.id);
      if (mounted)
        setState(() {
          _parentData = null;
          _notificationData = null;
        });
    }
  }

  Future<void> _logout() async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.signOut),
        content: Text(strings.signOutPrompt),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.cancel)),
          FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.signOut)),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(gatewayProvider.notifier).logoutPortal();
      if (mounted)
        setState(() {
          _staffData = null;
          _parentData = null;
          _notificationData = null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final gateway = ref.watch(gatewayProvider);
    final controller = ref.read(gatewayProvider.notifier);
    final portal = gateway.portal;
    final children = portal.children;
    final selectedChild = children.isEmpty
        ? null
        : children.firstWhere(
            (child) => child.id == _selectedChildId,
            orElse: () => children.first,
          );
    final canPair = gateway.isRunning && gateway.ip != '0.0.0.0';
    final gatewayUrl =
        canPair ? 'http://${gateway.ip}:${gateway.settings.port}' : '';

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: HeroHeader(
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              title: strings.gatewayPortal,
              subtitle: strings.pairWithDesktop,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: <Widget>[
                      Text(
                        strings.isArabic
                            ? 'ربط هذا الهاتف بتطبيق سطح المكتب'
                            : 'Pair this phone with the desktop app',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      if (canPair)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: QrImageView(
                            data: gatewayUrl,
                            version: QrVersions.auto,
                            size: 210,
                          ),
                        )
                      else
                        Container(
                          height: 210,
                          width: 210,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            gateway.ip == '0.0.0.0'
                                ? Icons.wifi_off_rounded
                                : Icons.power_off_rounded,
                            size: 48,
                          ),
                        ),
                      const SizedBox(height: 12),
                      SelectableText(
                          canPair ? gatewayUrl : strings.networkUnavailable,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                          '${strings.pairingCode}: ${gateway.settings.pairPin}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        canPair
                            ? (strings.isArabic
                                ? 'أدخل العنوان ورمز الربط في إعدادات ماسحات الهاتف على الحاسوب.'
                                : 'Enter this address and pairing code in the desktop scanner settings.')
                            : strings.gatewayStoppedHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (gatewayUrl.isNotEmpty)
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                                ClipboardData(text: gatewayUrl));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(strings.addressCopied)));
                            }
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: Text(strings.copyAddress),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _portalLoginOrData(context, strings, gateway, portal,
                    selectedChild, controller),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _portalLoginOrData(
    BuildContext context,
    AppStrings strings,
    GatewayState gateway,
    PortalSnapshot portal,
    PortalChild? selectedChild,
    GatewayController controller,
  ) {
    if (!portal.isStaff && !portal.isParent) {
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(strings.gatewayPortal,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                ButtonSegment<String>(
                    value: 'staff', label: Text(strings.staffTab)),
                ButtonSegment<String>(
                    value: 'parent', label: Text(strings.parentTab)),
              ],
              selected: <String>{_mode},
              onSelectionChanged: (value) =>
                  setState(() => _mode = value.first),
            ),
            const SizedBox(height: 12),
            Text(_mode == 'staff'
                ? strings.staffLoginDescription
                : strings.parentLoginDescription),
            const SizedBox(height: 12),
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                  labelText: strings.serverAddress,
                  hintText: strings.serverAddressHint),
            ),
            if (_mode == 'staff') ...<Widget>[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: InputDecoration(labelText: strings.role),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                      value: 'admin', child: Text(strings.adminRole)),
                  DropdownMenuItem(
                      value: 'employee', child: Text(strings.employeeRole)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _role = value);
                },
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: _mode == 'staff' ? 8 : 12,
              decoration: InputDecoration(
                labelText:
                    _mode == 'staff' ? strings.staffCode : strings.childCode,
                hintText: _mode == 'staff'
                    ? strings.staffCodeHint
                    : strings.childCodeHint,
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: gateway.portalBusy ? null : _signIn,
              icon: gateway.portalBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login_rounded),
              label:
                  Text(gateway.portalBusy ? strings.signingIn : strings.signIn),
            ),
            if (gateway.error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(strings.errorText(gateway.error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      );
    }

    if (portal.isStaff) {
      final staff = portal.staff!;
      return AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(strings.teacherDashboard,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('${strings.usernameLabel}: ${staff.name}'),
            Text('${strings.companionSchool}: ${staff.schoolName}'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: gateway.portalBusy ? null : _loadPortalData,
              icon: const Icon(Icons.dashboard_rounded),
              label: Text(strings.openDashboard),
            ),
            if (_staffData != null) ...<Widget>[
              const SizedBox(height: 12),
              SelectableText(_formatData(_staffData, strings)),
            ],
            TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: Text(strings.signOut),
            ),
          ],
        ),
      );
    }

    if (selectedChild == null) {
      return AppCard(
          padding: const EdgeInsets.all(16), child: Text(strings.noChildren));
    }
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(strings.parentChildren,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (portal.children.length > 1)
            DropdownButtonFormField<String>(
              value: selectedChild.id,
              decoration: InputDecoration(labelText: strings.selectChild),
              items: portal.children
                  .map((child) => DropdownMenuItem<String>(
                      value: child.id, child: Text(child.name)))
                  .toList(growable: false),
              onChanged: (id) async {
                setState(() => _selectedChildId = id);
                await _loadPortalData();
              },
            )
          else
            Text('${selectedChild.name} · ${selectedChild.classGroup}'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: gateway.portalBusy ? null : _loadPortalData,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(strings.attendance30),
          ),
          if (_parentData != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(strings.parentOverview,
                style: Theme.of(context).textTheme.titleSmall),
            SelectableText(_formatData(_parentData, strings)),
          ],
          const Divider(height: 24),
          Row(
            children: <Widget>[
              Expanded(
                  child: Text(strings.notifications,
                      style: Theme.of(context).textTheme.titleSmall)),
              TextButton(
                onPressed: _notificationRows.isEmpty
                    ? null
                    : () => _markNotificationsRead(selectedChild),
                child: Text(strings.markAllRead),
              ),
            ],
          ),
          if (_notificationRows.isEmpty)
            Text(strings.noNotifications)
          else
            ..._notificationRows.map((row) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(
                      (row['title'] ?? row['message'] ?? strings.notifications)
                          .toString()),
                  subtitle:
                      Text((row['created_at'] ?? row['date'] ?? '').toString()),
                )),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              TextButton.icon(
                onPressed: () => _removeChild(selectedChild),
                icon: const Icon(Icons.person_remove_alt_1_rounded),
                label: Text(strings.removeChild),
              ),
              TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded),
                label: Text(strings.signOut),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
