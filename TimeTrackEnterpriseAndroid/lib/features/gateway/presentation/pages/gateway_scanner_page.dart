import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/i18n/app_strings.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/offline_scan.dart';
import '../providers/gateway_provider.dart';

class GatewayScannerPage extends ConsumerStatefulWidget {
  const GatewayScannerPage({super.key});

  @override
  ConsumerState<GatewayScannerPage> createState() => _GatewayScannerPageState();
}

class _GatewayScannerPageState extends ConsumerState<GatewayScannerPage> {
  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manualCode = TextEditingController();
  String _mode = 'gateway';
  String? _lastCode;
  String? _lastResult;
  DateTime? _lastAcceptedAt;
  bool _submitting = false;

  @override
  void dispose() {
    _camera.dispose();
    _manualCode.dispose();
    super.dispose();
  }

  Future<void> _acceptCode(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || _submitting) return;

    final now = DateTime.now();
    if (code == _lastCode &&
        _lastAcceptedAt != null &&
        now.difference(_lastAcceptedAt!) < const Duration(milliseconds: 2500)) {
      if (mounted)
        setState(() => _lastResult = AppStrings.of(context).scannerIgnored);
      return;
    }

    _submitting = true;
    _lastAcceptedAt = now;
    String result;
    try {
      final controller = ref.read(gatewayProvider.notifier);
      if (_mode == 'offline') {
        final verdict = await controller.scanOffline(code);
        if (verdict == null) {
          result = AppStrings.of(context).errorText(
            ref.read(gatewayProvider).error ?? 'scannerNeedsSetup',
          );
        } else {
          final name = verdict.displayName.isEmpty ? code : verdict.displayName;
          final status = AppStrings.of(context).isArabic
              ? OfflineStatus.labelAr(verdict.status)
              : OfflineStatus.labelEn(verdict.status);
          result = AppStrings.of(context).scannerOfflineQueued(name, status);
        }
      } else {
        final sequence = controller.addGatewayScan(code);
        result = sequence > 0
            ? AppStrings.of(context).scannerQueued(sequence)
            : AppStrings.of(context).scannerIgnored;
      }
    } catch (error) {
      result = error.toString();
    }

    if (mounted) {
      setState(() {
        _lastCode = code;
        _lastResult = result;
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(result)));
    }

    await Future<void>.delayed(const Duration(milliseconds: 2500));
    _submitting = false;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final gateway = ref.watch(gatewayProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: HeroHeader(
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              title: strings.gatewayScanner,
              subtitle: strings.pairWithDesktop,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: SegmentedButton<String>(
                    segments: <ButtonSegment<String>>[
                      ButtonSegment<String>(
                        value: 'gateway',
                        icon: const Icon(Icons.desktop_windows_rounded),
                        label: Text(strings.scannerModeGateway),
                      ),
                      ButtonSegment<String>(
                        value: 'offline',
                        icon: const Icon(Icons.cloud_off_rounded),
                        label: Text(strings.scannerModeOffline),
                      ),
                    ],
                    selected: <String>{_mode},
                    onSelectionChanged: (value) =>
                        setState(() => _mode = value.first),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _mode == 'offline'
                      ? strings.scannerOfflineHint
                      : strings.scannerGatewayHint,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: MobileScanner(
                      controller: _camera,
                      onDetect: (capture) {
                        final value = capture.barcodes.isEmpty
                            ? null
                            : capture.barcodes.first.rawValue;
                        if (value != null) unawaited(_acceptCode(value));
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      TextField(
                        controller: _manualCode,
                        textInputAction: TextInputAction.done,
                        onSubmitted: _acceptCode,
                        decoration: InputDecoration(
                          labelText: strings.scannerManualHint,
                          prefixIcon: const Icon(Icons.keyboard_alt_outlined),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _submitting
                            ? null
                            : () => _acceptCode(_manualCode.text),
                        icon: const Icon(Icons.add_task_rounded),
                        label: Text(strings.submit),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.scannerLastScan,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(_lastCode ?? strings.scannerNoScan),
                      if (_lastResult != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          _lastResult!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        gateway.isRunning
                            ? '${strings.serverRunning} · ${gateway.ip}:${gateway.settings.port}'
                            : strings.gatewayStoppedHint,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: Wrap(
        spacing: 10,
        children: <Widget>[
          FloatingActionButton.small(
            heroTag: 'scanner_camera',
            onPressed: () => _camera.switchCamera(),
            tooltip: strings.scannerSwitchCamera,
            child: const Icon(Icons.cameraswitch_rounded),
          ),
          FloatingActionButton(
            heroTag: 'scanner_torch',
            onPressed: () => _camera.toggleTorch(),
            tooltip: strings.scannerTorch,
            child: const Icon(Icons.flash_on_rounded),
          ),
        ],
      ),
    );
  }
}
