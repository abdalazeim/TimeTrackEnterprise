import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/i18n/app_strings.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/app_logo.dart';

class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: AppColors.headerGradient,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -120,
              left: -80,
              child: _Glow(
                size: 320,
                color: AppColors.gold.withValues(alpha: 0.2),
              ),
            ),
            Positioned(
              bottom: -160,
              right: -70,
              child: _Glow(
                size: 360,
                color: AppColors.mint.withValues(alpha: 0.16),
              ),
            ),
            SafeArea(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        AppLogo(
                          size: 104,
                          background: Colors.white.withValues(alpha: 0.14),
                          showShadow: false,
                        ),
                        const SizedBox(height: 26),
                        Text(
                          AppConfig.appName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.appTagline,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                        const SizedBox(height: 38),
                        SizedBox(
                          width: 132,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: const LinearProgressIndicator(
                              minHeight: 4,
                              backgroundColor: Color(0x33FFFFFF),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.goldSoft,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          strings.preparingSession,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.startupHint,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
