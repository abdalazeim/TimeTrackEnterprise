import 'package:flutter/material.dart';

import '../../../../app/i18n/app_strings.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/app_ui.dart';

class GatewayAboutPage extends StatelessWidget {
  const GatewayAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: HeroHeader(
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              title: strings.gatewayAbout,
              subtitle: AppConfig.appName,
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
                        'Attendance Gateway Companion',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.isArabic
                            ? '‰Ÿ«„ »Ê«»… Õ÷Ê— „Õ·Ì… ·—»ÿ √ÃÂ“… «·Õ÷Ê— » ÿ»Ìﬁ ”ÿÕ «·„ﬂ » ⁄»— ‘»ﬂ… Wi-Fi «·„Õ·Ì….'
                            : 'Local attendance gateway system to connect attendance devices to the desktop app over local Wi-Fi.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      const _InfoRow(label: 'Version', value: '4.1.1'),
                      const Divider(height: 20),
                      _InfoRow(
                        label: strings.isArabic ? '«·ﬁ«·»' : 'Template',
                        value: AppConfig.appName,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
