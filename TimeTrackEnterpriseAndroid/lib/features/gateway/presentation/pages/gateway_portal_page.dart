import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/i18n/app_strings.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../providers/gateway_provider.dart';

class GatewayPortalPage extends ConsumerWidget {
  const GatewayPortalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final gateway = ref.watch(gatewayProvider);
    final ctrl = ref.read(gatewayProvider.notifier);
    final url = ctrl.serverUrl;

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: HeroHeader(
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      Text(
                        strings.isArabic
                            ? '«„”Õ Â–« «·—„“ ·—»ÿ  ÿ»Ìﬁ ”ÿÕ «·„ﬂ »'
                            : 'Scan this QR to pair with desktop app',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: gateway.isRunning ? url : 'http://${gateway.ip}:${gateway.port}',
                          version: QrVersions.auto,
                          size: 220,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        gateway.isRunning
                            ? url
                            : '${strings.serverStopped} - ${url}',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
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
