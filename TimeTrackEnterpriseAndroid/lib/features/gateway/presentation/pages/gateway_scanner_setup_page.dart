import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/i18n/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../providers/gateway_provider.dart';

class GatewayScannerSetupPage extends ConsumerWidget {
  const GatewayScannerSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final gateway = ref.watch(gatewayProvider);
    final controller = ref.read(gatewayProvider.notifier);
    final address = gateway.ip == '0.0.0.0'
        ? null
        : 'http://${gateway.ip}:${gateway.settings.port}';

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: HeroHeader(
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              title: strings.gatewayScannerSetup,
              subtitle: strings.gatewayScanner,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(Icons.qr_code_scanner_rounded, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              strings.companionStatus,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Icon(
                            gateway.isRunning
                                ? Icons.check_circle_rounded
                                : Icons.warning_rounded,
                            color: gateway.isRunning
                                ? Colors.green
                                : Theme.of(context).colorScheme.error,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(gateway.isRunning
                          ? strings.serverRunning
                          : strings.serverStopped),
                      const SizedBox(height: 4),
                      SelectableText(address ??
                          (strings.isArabic
                              ? 'اتصل بشبكة Wi-Fi أو Ethernet لعرض عنوان الربط.'
                              : 'Connect to Wi-Fi or Ethernet to get a pairing address.')),
                      const SizedBox(height: 4),
                      Text('${strings.serverPort}: ${gateway.settings.port}'),
                      const SizedBox(height: 4),
                      Text(
                          '${strings.pairingCode}: ${gateway.settings.pairPin}'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: gateway.busy
                            ? null
                            : gateway.isRunning
                                ? controller.stopServer
                                : controller.startServer,
                        icon: Icon(gateway.isRunning
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded),
                        label: Text(gateway.isRunning
                            ? strings.stopServer
                            : strings.startServer),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => context.push(Routes.gatewayPortal),
                        icon: const Icon(Icons.qr_code_rounded),
                        label: Text(strings.pairWithDesktop),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(Routes.gatewayScanner),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(strings.gatewayScanner),
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
                        strings.instructions,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.isArabic
                            ? '1. صِل الهاتف والحاسوب بالشبكة المحلية نفسها عبر Wi-Fi أو Ethernet.\n2. اترك البوابة قيد التشغيل.\n3. أضف عنوان الهاتف ورمز الربط من إعدادات الماسح في TimeTrack Enterprise.\n4. افتح الماسح وامسح بطاقة الطالب؛ ستصل المسحات إلى الحاسوب عبر /scans.'
                            : '1. Connect the phone and desktop to the same Wi-Fi or Ethernet LAN.\n2. Keep the gateway running.\n3. Add this address and pairing code in TimeTrack Enterprise scanner settings.\n4. Scan a student card; scans reach the desktop through /scans.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
