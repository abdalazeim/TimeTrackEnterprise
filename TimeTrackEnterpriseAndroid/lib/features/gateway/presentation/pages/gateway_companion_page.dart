import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/i18n/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../providers/gateway_provider.dart';

class GatewayCompanionPage extends ConsumerStatefulWidget {
  const GatewayCompanionPage({super.key});

  @override
  ConsumerState<GatewayCompanionPage> createState() =>
      _GatewayCompanionPageState();
}

class _GatewayCompanionPageState extends ConsumerState<GatewayCompanionPage> {
  final TextEditingController _server = TextEditingController();
  final TextEditingController _passcode = TextEditingController();
  bool _discovering = false;

  @override
  void initState() {
    super.initState();
    _server.text = ref.read(gatewayProvider).companion.serverUrl;
  }

  @override
  void dispose() {
    _server.dispose();
    _passcode.dispose();
    super.dispose();
  }

  Future<void> _discover() async {
    setState(() => _discovering = true);
    final found = await ref.read(gatewayProvider.notifier).discoverServer();
    if (!mounted) return;
    setState(() {
      _discovering = false;
      if (found != null) _server.text = found;
    });
    final strings = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(found == null
              ? strings.serverNotFound
              : '${strings.serverFound}: $found')),
    );
  }

  Future<void> _connect() async {
    final controller = ref.read(gatewayProvider.notifier);
    final result = await controller.connectScanner(
      server: _server.text,
      passcode: _passcode.text,
    );
    if (!mounted) return;
    final strings = AppStrings.of(context);
    final message = result == null
        ? ref.read(gatewayProvider).error ?? strings.unknownError
        : result.ok
            ? strings.scannerConnected
            : result.pending
                ? strings.scannerPending
                : result.blocked
                    ? strings.scannerBlocked
                    : result.message;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _disconnect() async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.disconnectScanner),
        content: Text(strings.disconnectScannerPrompt),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.disconnectScanner),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(gatewayProvider.notifier).forgetScanner();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final gateway = ref.watch(gatewayProvider);
    final companion = gateway.companion;
    final status = companion.isApproved
        ? strings.approved
        : companion.isPending
            ? strings.pendingApproval
            : companion.isBlocked
                ? strings.blocked
                : strings.notConnected;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: HeroHeader(
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              title: strings.gatewayCompanion,
              subtitle: strings.gatewayTitle,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        strings.companionStatus,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      _StatusRow(
                          label: strings.serverAddress,
                          value: companion.serverUrl.isEmpty
                              ? '—'
                              : companion.serverUrl),
                      _StatusRow(
                          label: strings.companionUser,
                          value: companion.displayName.isEmpty
                              ? '—'
                              : companion.displayName),
                      _StatusRow(
                          label: strings.companionSchool,
                          value: companion.schoolName.isEmpty
                              ? '—'
                              : companion.schoolName),
                      _StatusRow(
                          label: strings.companionRole,
                          value: companion.roleLabel.isEmpty
                              ? '—'
                              : companion.roleLabel),
                      _StatusRow(
                          label: strings.offlineStatusLabel, value: status),
                      if (companion.pairCode.isNotEmpty)
                        _StatusRow(
                            label: strings.pairCodeLabel,
                            value: companion.pairCode),
                      if (companion.hasSession) ...<Widget>[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: gateway.busy
                              ? null
                              : () async {
                                  final result = await ref
                                      .read(gatewayProvider.notifier)
                                      .refreshCompanion();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(result?.message ??
                                            strings.unknownError)),
                                  );
                                },
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(strings.refreshStatus),
                        ),
                        TextButton.icon(
                          onPressed: _disconnect,
                          icon: const Icon(Icons.link_off_rounded),
                          label: Text(strings.disconnectScanner),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              ref.read(gatewayProvider.notifier).syncOffline(),
                          icon: const Icon(Icons.sync_rounded),
                          label: Text(strings.syncOffline),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!companion.hasSession) ...<Widget>[
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          strings.openScannerSetup,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(strings.scannerSetupDescription),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _server,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: strings.serverAddress,
                            hintText: strings.serverAddressHint,
                            prefixIcon: const Icon(Icons.dns_rounded),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: _discovering ? null : _discover,
                            icon: _discovering
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.wifi_find_rounded),
                            label: Text(_discovering
                                ? strings.discovering
                                : strings.discoverServer),
                          ),
                        ),
                        TextField(
                          controller: _passcode,
                          keyboardType: TextInputType.number,
                          maxLength: 8,
                          decoration: InputDecoration(
                            labelText: strings.passcode,
                            hintText: strings.passcodeHint,
                            prefixIcon: const Icon(Icons.password_rounded),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: gateway.busy ? null : _connect,
                          icon: gateway.busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.link_rounded),
                          label: Text(gateway.busy
                              ? strings.connecting
                              : strings.connectScanner),
                        ),
                        const SizedBox(height: 6),
                        Text(strings.scannerLoginRequiredNote,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => context.push(Routes.gatewayScannerSetup),
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(strings.gatewayScannerSetup),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push(Routes.gatewayPortal),
                  icon: const Icon(Icons.account_circle_outlined),
                  label: Text(strings.gatewayPortal),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: <Widget>[
          Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
