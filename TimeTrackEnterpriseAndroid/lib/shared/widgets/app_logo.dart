import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Neutral placeholder mark. Replace it with a project logo when branding is set.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 84,
    this.showShadow = true,
    this.background,
  });

  final double size;
  final bool showShadow;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: background == null
            ? const LinearGradient(
                begin: Alignment.bottomRight,
                end: Alignment.topLeft,
                colors: AppColors.brandGradient,
              )
            : null,
        color: background,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: size * 0.012,
        ),
        boxShadow: showShadow
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.deepForest.withValues(alpha: 0.32),
                  blurRadius: size * 0.32,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      child: Icon(
        Icons.dashboard_customize_rounded,
        size: size * 0.54,
        color: AppColors.goldSoft,
      ),
    );
  }
}
