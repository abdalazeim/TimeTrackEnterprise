import 'package:flutter/material.dart';

import '../../../../app/i18n/app_strings.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../data/gateway_info.dart';

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
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppConfig.appName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.isArabic
                            ? 'بوابة محلية لربط أجهزة المسح وإرسال الرسائل مع نظام TimeTrack Enterprise عبر الشبكة.'
                            : 'A local gateway for attendance scanners and SMS delivery on the TimeTrack Enterprise network.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        label: strings.isArabic ? 'الإصدار' : 'Version',
                        value: GatewayInfo.version,
                      ),
                      const Divider(height: 20),
                      _InfoRow(
                        label:
                            strings.isArabic ? 'الخادم المحلي' : 'Local server',
                        value: 'HTTP · /health · /scans · /pair · /send',
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
    );
  }
}
