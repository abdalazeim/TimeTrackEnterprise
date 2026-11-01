import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/i18n/app_strings.dart';
import '../../../../shared/widgets/app_ui.dart';

class GatewayScannerPage extends ConsumerStatefulWidget {
  const GatewayScannerPage({super.key});

  @override
  ConsumerState<GatewayScannerPage> createState() => _GatewayScannerPageState();
}

class _GatewayScannerPageState extends ConsumerState<GatewayScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  String? lastCode;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

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
              title: strings.gatewayScanner,
              subtitle: strings.pairWithDesktop,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                AppCard(
                  padding: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: MobileScanner(
                      controller: controller,
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        if (barcodes.isEmpty) return;
                        final value = barcodes.first.rawValue;
                        if (value == null || value == lastCode) return;
                        setState(() => lastCode = value);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(value)),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        strings.gatewayScanner,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        lastCode == null
                            ? (strings.isArabic
                                ? 'æÌå ÇáßÇãíÑÇ äÍæ ÑãÒ QR ááÑÈØ'
                                : 'Point camera to pairing QR code')
                            : lastCode!,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => controller.toggleTorch(),
        child: const Icon(Icons.flash_on_rounded),
      ),
    );
  }
}
