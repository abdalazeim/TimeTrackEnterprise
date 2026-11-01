import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/i18n/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/offline_scan.dart';
import '../providers/gateway_provider.dart';

class GatewayHomePage extends ConsumerStatefulWidget {
  const GatewayHomePage({super.key});

  @override
  ConsumerState<GatewayHomePage> createState() => _GatewayHomePageState();
}

class _GatewayHomePageState extends ConsumerState<GatewayHomePage> {
  bool _showKey = false;
  bool _showPin = true;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final state = ref.watch(gatewayProvider);
    final ctrl = ref.read(gatewayProvider.notifier);
    final address = 'http://${state.ip == '0.0.0.0' ? '127.0.0.1' : state.ip}:${state.settings.port}';

    ref.listen<GatewayState>(gatewayProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        _snack(strings.errorText(next.error));
      } else if (next.message != null && next.message != previous?.message) {
        _snack(strings.errorText(next.message));
      }
    });

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: HeroHeader(
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              title: strings.gatewayTitle,
              subtitle: strings.gatewaySubtitle,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  HeroIconButton(
                    icon: Icons.info_outline_rounded,
                    tooltip: strings.gatewayAbout,
                    onTap: () => context.push(Routes.gatewayAbout),
                  ),
                  const SizedBox(width: 4),
                  HeroIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: strings.refresh,
                    onTap: state.busy ? null : ctrl.refresh,
                  ),
                ],
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: StatPill(
                      label: strings.pendingScans,
                      value: '${state.runtime.scansPending}',
                      icon: Icons.qr_code_2_rounded,
                      onDark: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatPill(
                      label: strings.offlineToday,
                      value: '${state.stats.today}',
                      icon: Icons.fact_check_rounded,
                      onDark: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatPill(
                      label: strings.offlinePending,
                      value: '${state.stats.pending}',
                      icon: Icons.cloud_upload_rounded,
                      onDark: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppBanner(
                      message: strings.errorText(state.error),
                      icon: Icons.error_outline_rounded,
                      tone: AppColors.danger,
                    ),
                  ),
                if (!state.initialized)
                  const AppCard(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...<Widget>[
                  _StatusCard(
                    address: address,
                    state: state,
                    strings: strings,
                    onStart: ctrl.startServer,
                    onStop: ctrl.stopServer,
                    onRestart: ctrl.restartServer,
                    onCopy: () => _copy(context, address, strings.copied),
                  ),
                  const SizedBox(height: 22),
                  SectionHeader(
                    title: strings.pairingCode,
                    subtitle: strings.pairingHint,
                    icon: Icons.key_rounded,
                  ),
                  _PairingCard(
                    strings: strings,
                    state: state,
                    showPin: _showPin,
                    showKey: _showKey,
                    onTogglePin: () => setState(() => _showPin = !_showPin),
                    onToggleKey: () => setState(() => _showKey = !_showKey),
                    onRegeneratePin: () => _confirmRegeneratePin(
                      context,
                      strings,
                      ctrl.regeneratePairPin,
                    ),
                    onRegenerateKey: () => _confirmRegenerateKey(
                      context,
                      strings,
                      ctrl.regenerateApiKey,
                    ),
                    onTogglePairing: ctrl.setPairingEnabled,
                    onEditPort: () => _editPort(context, strings, ctrl),
                    onCopy: (value) => _copy(context, value, strings.copied),
                    onEditKey: () => _editKey(context, strings, ctrl),
                  ),
                  const SizedBox(height: 22),
                  SectionHeader(
                    title: strings.gatewayCompanion,
                    subtitle: strings.sharedNetworkHint,
                    icon: Icons.devices_rounded,
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _QuickAction(
                        icon: Icons.qr_code_scanner_rounded,
                        label: strings.gatewayScanner,
                        onTap: () => context.push(Routes.gatewayScanner),
                      ),
                      _QuickAction(
                        icon: Icons.tune_rounded,
                        label: strings.gatewayScannerSetup,
                        onTap: () => context.push(Routes.gatewayScannerSetup),
                      ),
                      _QuickAction(
                        icon: Icons.hub_rounded,
                        label: strings.gatewayPortal,
                        onTap: () => context.push(Routes.gatewayPortal),
                      ),
                      _QuickAction(
                        icon: Icons.phone_android_rounded,
                        label: strings.openCompanion,
                        onTap: () => context.push(Routes.gatewayCompanion),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SectionHeader(
                    title: strings.scanQueue,
                    subtitle: strings.scannerOfflineHint,
                    icon: Icons.playlist_add_check_rounded,
                    action: TextButton.icon(
                      onPressed: state.syncing ? null : ctrl.syncOffline,
                      icon: state.syncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        state.syncing ? strings.syncing : strings.syncNow,
                      ),
                    ),
                  ),
                  _OfflineQueueCard(
                    strings: strings,
                    state: state,
                    onClearScans: ctrl.clearGatewayScans,
                    onSync: ctrl.syncOffline,
                    onOpenScanner: () => context.push(Routes.gatewayScanner),
                  ),
                  const SizedBox(height: 22),
                  SectionHeader(
                    title: strings.gatewaySettings,
                    subtitle: strings.gatewayStatus,
                    icon: Icons.settings_rounded,
                  ),
                  AppCard(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: <Widget>[
                        SwitchListTile(
                          value: state.settings.autoStart,
                          onChanged: ctrl.toggleAutoStart,
                          title: Text(strings.autoStart),
                          subtitle: Text(strings.autoStartHint),
                          secondary:
                              const Icon(Icons.power_settings_new_rounded),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          value: state.settings.keepAwake,
                          onChanged: ctrl.toggleKeepAwake,
                          title: Text(strings.keepAwake),
                          subtitle: Text(strings.keepAwakeHint),
                          secondary: const Icon(Icons.battery_charging_full_rounded),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.send_rounded),
                          title: Text(strings.sendTestSms),
                          subtitle: Text(
                            state.portal.isStaff
                                ? strings.smsQueued
                                : strings.smsStaffRequired,
                          ),
                          trailing: const Icon(Icons.chevron_left_rounded),
                          onTap: () => _sendTestSms(context, strings, ctrl),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SectionHeader(
                    title: strings.instructions,
                    subtitle: strings.pairWithDesktop,
                    icon: Icons.help_outline_rounded,
                  ),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      strings.instructionsText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(
    BuildContext context,
    String value,
    String confirmation,
  ) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(confirmation)));
  }

  Future<void> _confirmRegeneratePin(
    BuildContext context,
    AppStrings strings,
    Future<void> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.pairingCode),
        content: Text(strings.regeneratePinPrompt),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.regenerate),
          ),
        ],
      ),
    );
    if (confirmed == true) await action();
  }

  Future<void> _confirmRegenerateKey(
    BuildContext context,
    AppStrings strings,
    Future<void> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.apiKey),
        content: Text(strings.regenerateKeyPrompt),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.regenerate),
          ),
        ],
      ),
    );
    if (confirmed == true) await action();
  }

  Future<void> _editPort(
    BuildContext context,
    AppStrings strings,
    GatewayController ctrl,
  ) async {
    final state = ref.read(gatewayProvider);
    final controller =
        TextEditingController(text: state.settings.port.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.portLabel),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: InputDecoration(
            hintText: strings.portHint,
            errorText: null,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed < 1024 || parsed > 65535) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(strings.invalidPort)),
                );
                return;
              }
              Navigator.of(dialogContext).pop(parsed);
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await ctrl.setPort(value);
    } catch (_) {
      // The controller stores a localised error code in the state.
    }
  }

  Future<void> _editKey(
    BuildContext context,
    AppStrings strings,
    GatewayController ctrl,
  ) async {
    final state = ref.read(gatewayProvider);
    final controller = TextEditingController(text: state.settings.apiKey);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.apiKey),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: strings.apiKeyHint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(strings.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await ctrl.updateApiKey(value);
    } catch (_) {
      // Ignore; the provider exposes the validation error.
    }
  }

  Future<void> _sendTestSms(
    BuildContext context,
    AppStrings strings,
    GatewayController ctrl,
  ) async {
    final phone = TextEditingController();
    final message = TextEditingController(
      text: strings.isArabic
          ? 'رسالة تجريبية من بوابة الحضور.'
          : 'Test message from the Attendance Gateway.',
    );
    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.sendTestSms),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: strings.phoneNumber,
                  hintText: '+9665xxxxxxxx',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: message,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: strings.messageBody),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.send),
          ),
        ],
      ),
    );
    final phoneValue = phone.text.trim();
    final messageValue = message.text.trim();
    phone.dispose();
    message.dispose();
    if (send != true) return;
    if (phoneValue.isEmpty || messageValue.isEmpty) {
      _snack(strings.phoneRequired);
      return;
    }
    final result = await ctrl.sendSms(phoneValue, messageValue);
    _snack(result.ok ? strings.smsQueued : result.detail);
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.address,
    required this.state,
    required this.strings,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
    required this.onCopy,
  });

  final String address;
  final GatewayState state;
  final AppStrings strings;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;
  final Future<void> Function() onRestart;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final running = state.runtime.running;
    return AppCard(
      padding: const EdgeInsets.all(16),
      accent: running ? AppColors.success : AppColors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconBadge(
                icon: running ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                tone: running ? AppColors.success : AppColors.amber,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      running ? strings.serverRunning : strings.serverStopped,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      state.runtime.starting
                          ? strings.gatewayStarting
                          : (running
                              ? strings.gatewayRunningHint
                              : strings.gatewayStoppedHint),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (running ? AppColors.success : AppColors.amber)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  running ? strings.approved : strings.notConnected,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: running ? AppColors.success : AppColors.amber,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.lan_rounded, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        address,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${strings.deviceIp}: ${state.ip} • ${strings.serverPort}: ${state.settings.port}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: strings.copyAddress,
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
          ),
          if (state.runtime.error != null) ...<Widget>[
            const SizedBox(height: 10),
            AppBanner(
              message: state.runtime.error!,
              icon: Icons.error_outline_rounded,
              tone: AppColors.danger,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.busy
                      ? null
                      : (running ? onStop : onStart),
                  icon: Icon(
                    running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    running ? strings.stopServer : strings.startServer,
                  ),
                ),
              ),
              if (running) ...<Widget>[
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: strings.restartServer,
                  onPressed: state.busy ? null : onRestart,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PairingCard extends StatelessWidget {
  const _PairingCard({
    required this.strings,
    required this.state,
    required this.showPin,
    required this.showKey,
    required this.onTogglePin,
    required this.onToggleKey,
    required this.onRegeneratePin,
    required this.onRegenerateKey,
    required this.onTogglePairing,
    required this.onEditPort,
    required this.onCopy,
    required this.onEditKey,
  });

  final AppStrings strings;
  final GatewayState state;
  final bool showPin;
  final bool showKey;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleKey;
  final VoidCallback onRegeneratePin;
  final VoidCallback onRegenerateKey;
  final Future<void> Function(bool) onTogglePairing;
  final VoidCallback onEditPort;
  final void Function(String) onCopy;
  final VoidCallback onEditKey;

  @override
  Widget build(BuildContext context) {
    final settings = state.settings;
    final pin = settings.pairPin;
    final key = settings.apiKey;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.pairingCode,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      showPin
                          ? (pin.isEmpty ? '—' : pin)
                          : '••••',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: showPin ? strings.hideSecret : strings.showSecret,
                onPressed: pin.isEmpty ? null : onTogglePin,
                icon: Icon(
                  showPin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                ),
              ),
              IconButton(
                tooltip: strings.copy,
                onPressed: pin.isEmpty ? null : () => onCopy(pin),
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton(
                tooltip: strings.regenerate,
                onPressed: onRegeneratePin,
                icon: const Icon(Icons.autorenew_rounded),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: pin.isNotEmpty,
            onChanged: onTogglePairing,
            title: Text(strings.pairingEnabled),
            subtitle: Text(strings.pairingHint),
            secondary: const Icon(Icons.link_rounded),
          ),
          const Divider(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      strings.apiKey,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      showKey ? key : '••••••••••••',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: showKey ? strings.hideSecret : strings.showSecret,
                onPressed: onToggleKey,
                icon: Icon(
                  showKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                ),
              ),
              IconButton(
                tooltip: strings.copy,
                onPressed: key.isEmpty ? null : () => onCopy(key),
                icon: const Icon(Icons.copy_rounded),
              ),
              IconButton(
                tooltip: strings.regenerate,
                onPressed: onRegenerateKey,
                icon: const Icon(Icons.autorenew_rounded),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            strings.apiKeyHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Divider(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_ethernet_rounded),
            title: Text(strings.portLabel),
            subtitle: Text(settings.port.toString()),
            trailing: TextButton(
              onPressed: onEditPort,
              child: Text(strings.save),
            ),
          ),
          const Divider(height: 20),
          Row(
            children: <Widget>[
              const Icon(Icons.badge_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${strings.deviceIdLabel}: ${settings.deviceId}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                onPressed: () => onCopy(settings.deviceId),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(strings.copy),
              ),
            ],
          ),
          TextButton.icon(
            onPressed: onEditKey,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(strings.apiKey),
          ),
        ],
      ),
    );
  }
}

class _OfflineQueueCard extends StatelessWidget {
  const _OfflineQueueCard({
    required this.strings,
    required this.state,
    required this.onClearScans,
    required this.onSync,
    required this.onOpenScanner,
  });

  final AppStrings strings;
  final GatewayState state;
  final VoidCallback onClearScans;
  final Future<void> Function() onSync;
  final VoidCallback onOpenScanner;

  @override
  Widget build(BuildContext context) {
    final recent = state.recent;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              StatPill(
                label: strings.offlineToday,
                value: '${state.stats.today}',
                icon: Icons.check_circle_outline_rounded,
                tone: AppColors.success,
              ),
              StatPill(
                label: strings.offlinePending,
                value: '${state.stats.pending}',
                icon: Icons.schedule_rounded,
                tone: AppColors.amber,
              ),
              StatPill(
                label: strings.receivedScans,
                value: '${state.runtime.scansReceived}',
                icon: Icons.download_rounded,
                tone: AppColors.info,
              ),
            ],
          ),
          const Divider(height: 24),
          if (recent.isEmpty)
            Text(
              strings.noScans,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ...recent.take(4).map(
                  (scan) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          scan.synced
                              ? Icons.cloud_done_rounded
                              : Icons.cloud_upload_rounded,
                          size: 18,
                          color: scan.synced
                              ? AppColors.success
                              : AppColors.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            scan.studentName.isEmpty
                                ? scan.code
                                : scan.studentName,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          strings.offlineStatus(scan.status),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scan.status == OfflineStatus.present
                                        ? AppColors.success
                                        : AppColors.amber,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClearScans,
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: Text(strings.clearQueue),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: state.syncing ? null : onSync,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(
                    state.syncing ? strings.syncing : strings.syncNow,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onOpenScanner,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
            label: Text(strings.gatewayScanner),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: (MediaQuery.of(context).size.width - 18 * 2 - 10) / 2,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            IconBadge(icon: icon, tone: AppColors.primary, size: 42),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
