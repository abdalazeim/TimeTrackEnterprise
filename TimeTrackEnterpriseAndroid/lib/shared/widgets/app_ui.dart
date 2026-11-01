import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/app_typography.dart';

/// Shared UI components that give all screens a consistent and professional look.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accent,
    this.gradient,
    this.borderRadius = 20,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? accent;
  final Gradient? gradient;
  final double borderRadius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final hasGradient = gradient != null;

    final decoration = BoxDecoration(
      color: hasGradient ? null : context.surfaceCard,
      gradient: gradient,
      borderRadius: radius,
      border: border
          ? Border.all(
              color: accent?.withValues(alpha: 0.45) ?? context.hairline,
              width: accent != null ? 1.2 : 1,
            )
          : null,
      boxShadow: hasGradient
          ? <BoxShadow>[
              BoxShadow(
                color: AppColors.deepForest.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ]
          : <BoxShadow>[
              BoxShadow(
                color: AppColors.deepForest
                    .withValues(alpha: context.isNight ? 0.18 : 0.045),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
    );

    final content = Padding(padding: padding, child: child);
    final body = onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: content,
            ),
          );

    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: <Widget>[
            if (accent != null)
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        accent!,
                        accent!.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
              ),
            body,
          ],
        ),
      ),
    );
  }
}

/// ????? ??? ?? ???? ???? ??? ???????.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.action,
    this.icon,
    this.color,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            IconBadge(icon: icon!, tone: tone, size: 38),
            const SizedBox(width: 10),
          ] else ...<Widget>[
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.mutedColor,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// ???? ?????? ?????? ???? ???????? ????? ??????.
class IconBadge extends StatelessWidget {
  const IconBadge({
    required this.icon,
    required this.tone,
    super.key,
    this.size = 42,
    this.radius = 13,
    this.solid = false,
  });

  final IconData icon;
  final Color tone;
  final double size;
  final double radius;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: solid
              ? <Color>[tone, Color.lerp(tone, Colors.black, 0.22)!]
              : <Color>[
                  tone.withValues(alpha: 0.18),
                  tone.withValues(alpha: 0.07),
                ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: tone.withValues(alpha: solid ? 0.4 : 0.22),
        ),
      ),
      child: Icon(
        icon,
        size: size * 0.5,
        color: solid ? Colors.white : tone,
      ),
    );
  }
}

/// ?? ????? ?????? ???? ??? ????.
class GradientButton extends StatelessWidget {
  const GradientButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.loading = false,
    this.height = 54,
    this.colors = const <Color>[AppColors.forest, AppColors.emerald],
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(16);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.62,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: enabled
                ? colors
                : <Color>[
                    colors.first.withValues(alpha: 0.7),
                    colors.last.withValues(alpha: 0.7),
                  ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.first.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: height,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (icon != null) ...<Widget>[
                            Icon(icon, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: const TextStyle(
                              fontFamily: AppTypography.family,
                              color: Colors.white,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ????? ????? ????? ??????? ???? ????????? ?????????.
class StatPill extends StatelessWidget {
  const StatPill({
    required this.label,
    required this.value,
    super.key,
    this.icon,
    this.tone,
    this.onDark = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? tone;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? Theme.of(context).colorScheme.primary;
    final foreground = onDark ? Colors.white : context.inkColor;
    final muted =
        onDark ? Colors.white.withValues(alpha: 0.72) : context.mutedColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: onDark
                    ? Colors.white.withValues(alpha: 0.16)
                    : color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 17,
                color: onDark ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 9),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                value,
                style: AppTypography.numeric(
                  color: foreground,
                  size: 16,
                ),
              ),
              if (label.isNotEmpty)
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: muted,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ?????? ?????? ???? ??????? ????????.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.leading,
    this.trailing,
    this.child,
    this.gradient = AppColors.headerGradient,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 22),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? child;
  final List<Color> gradient;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: gradient,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _HeaderPatternPainter()),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: padding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (leading != null) ...<Widget>[
                          leading!,
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              if (subtitle != null)
                                Text(
                                  subtitle!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.78),
                                      ),
                                ),
                            ],
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                    if (child != null) ...<Widget>[
                      const SizedBox(height: 18),
                      child!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ?? ?????? ???? ??????? ???? [HeroHeader] ??? ??????? ????????.
class HeroIconButton extends StatelessWidget {
  const HeroIconButton({
    required this.icon,
    required this.onTap,
    super.key,
    this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// ?????? ?????? ?????? ???????: ?? ???? + ????? + ??? + ???????.
class PageHero extends StatelessWidget {
  const PageHero({
    required this.title,
    super.key,
    this.subtitle,
    this.actions = const <Widget>[],
    this.child,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return HeroHeader(
      leading: showBack
          ? HeroIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: '????',
              onTap: () => Navigator.of(context).maybePop(),
            )
          : null,
      title: title,
      subtitle: subtitle,
      trailing: actions.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: actions),
      child: child,
    );
  }
}

class _HeaderPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          AppColors.gold.withValues(alpha: 0.22),
          AppColors.gold.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.86, size.height * 0.18),
          radius: size.width * 0.5,
        ),
      );
    canvas.drawRect(Offset.zero & size, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.95),
      size.width * 0.34,
      ring,
    );
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.62),
      size.width * 0.18,
      ring,
    );

    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.02, size.height * 0.92),
      Offset(size.width * 0.42, size.height * 1.08),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Alert/info bar with semantic color.
class AppBanner extends StatelessWidget {
  const AppBanner({
    required this.message,
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.tone = AppColors.info,
    this.action,
  });

  final String message;
  final IconData icon;
  final Color tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 19, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.inkColor,
                    height: 1.5,
                  ),
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(width: 8),
            action!,
          ],
        ],
      ),
    );
  }
}

/// ???? ????? ?????? ????? ??? ????????.
class ShimmerBone extends StatefulWidget {
  const ShimmerBone({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 10,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<ShimmerBone> createState() => _ShimmerBoneState();
}

class _ShimmerBoneState extends State<ShimmerBone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base =
        context.isNight ? AppColors.nightLine : const Color(0xFFE7EDE7);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: Alignment(_controller.value * 2, 0),
              colors: <Color>[
                base,
                Color.lerp(base, Colors.white, 0.55)!,
                base,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ???? ????? ??????? ?????? ?????? ???????.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    required this.name,
    super.key,
    this.size = 46,
    this.onDark = false,
  });

  final String name;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().substring(0, 1);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: onDark
            ? LinearGradient(
                colors: <Color>[
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.12),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.brandGradient,
              ),
        shape: BoxShape.circle,
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: AppTypography.family,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
