import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/i18n/app_strings.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../providers/gateway_provider.dart';

class GatewayCompanionPage extends ConsumerWidget {
  const GatewayCompanionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final gateway = ref.watch(gatewayProvider);
    final ctrl = ref.read(gatewayProvider.notifier);

    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: HeroHeader(
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.isArabic ? 'Õ«·… «·„”«⁄œ' : 'Companion Status',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      _StatusRow(
                        icon: Icons.wifi_tethering_rounded,
                        label: strings.serverAddress,
                        value: ctrl.serverUrl,
                      ),
                      const Divider(height: 24),
                      _StatusRow(
                        icon: Icons.power_settings_new_rounded,
                        label: strings.isArabic ? 'Õ«·… «·Œœ„…' : 'Service Status',
                        value: gateway.isRunning
                            ? strings.serverRunning
                            : strings.serverStopped,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    strings.isArabic
                        ? 'Ì⁄„· Â–« «·„”«⁄œ ﬂÃ”— „Õ·Ì »Ì‰ √ÃÂ“… «·Õ÷Ê— Ê ÿ»Ìﬁ ”ÿÕ «·„ﬂ » ⁄·Ï ‰›” «·‘»ﬂ….'
                        : 'This companion acts as a local bridge between attendance devices and the desktop app on the same network.',
                    style: Theme.of(context).textTheme.bodyMedium,
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
