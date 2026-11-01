import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/i18n/app_strings.dart';
import '../../../../shared/widgets/app_ui.dart';

class GatewayScannerSetupPage extends ConsumerWidget {
  const GatewayScannerSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              title: strings.gatewayScannerSetup,
              subtitle: strings.gatewayScanner,
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
                        strings.isArabic ? '≈⁄œ«œ ﬁ«—∆ «·»«—ﬂÊœ' : 'Barcode Reader Setup',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        strings.isArabic
                            ? 'Ì„ﬂ‰ «” Œœ«„ ﬂ«„Ì—« «·ÃÂ«“ ﬂ‹ „«”Õ QR ·—»ÿ «·√ÃÂ“… √Ê  „—Ì— —„Ê“ «·Õ÷Ê— ≈·Ï «·»Ê«»… «·„Õ·Ì….'
                            : 'Use device camera as a QR scanner to pair devices or pass attendance codes to the local gateway.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        value: true,
                        onChanged: (_) {},
                        title: Text(strings.isArabic ? ' ›⁄Ì· «·„«”Õ' : 'Enable Scanner'),
                        secondary: const Icon(Icons.qr_code_rounded),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: true,
                        onChanged: (_) {},
                        title: Text(strings.isArabic ? ' ‘€Ì· «·›·«‘  ·ﬁ«∆Ì« ⁄‰œ «·Õ«Ã…' : 'Auto-enable flashlight when needed'),
                        secondary: const Icon(Icons.flashlight_on_rounded),
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
