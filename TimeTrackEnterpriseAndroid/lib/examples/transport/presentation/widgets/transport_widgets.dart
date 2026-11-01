import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../shared/widgets/app_ui.dart';
import 'transport_format.dart';

class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.trailing,
    this.icon,
    this.padding = const EdgeInsets.all(16),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData? icon;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                IconBadge(icon: icon!, tone: scheme.primary, size: 36),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.mutedColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          child,
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, super.key, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(context, status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: compact ? 5 : 6,
            height: compact ? 5 : 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              fontFamily: AppTypography.family,
              color: color,
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    super.key,
    this.hint,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            tone.withValues(alpha: 0.13),
            tone.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: tone, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.numeric(color: tone, size: 17),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.mutedColor,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: tone),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CachedBanner extends StatelessWidget {
  const CachedBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return AppBanner(
      icon: Icons.cloud_off_rounded,
      tone: AppColors.goldDeep,
      message: message ??
          'لا يوجد اتصال بالخادم — تُعرض آخر نسخة محفوظة على الجهاز.',
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.icon,
    super.key,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
      child: Column(
        children: <Widget>[
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  scheme.primary.withValues(alpha: 0.16),
                  scheme.primary.withValues(alpha: 0.05),
                ],
              ),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Icon(icon, size: 34, color: scheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.mutedColor,
                height: 1.6,
              ),
            ),
          ],
          if (action != null) ...<Widget>[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.error,
    required this.onRetry,
    super.key,
    this.title = 'تعذر تحميل البيانات',
  });

  final Object error;
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          IconBadge(
            icon: Icons.cloud_off_rounded,
            tone: scheme.error,
            size: 50,
            radius: 16,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            errorMessage(error),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.mutedColor,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key, this.height = 180});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

/// هيكل تحميل لقوائم البطاقات.
class LoadingListSkeleton extends StatelessWidget {
  const LoadingListSkeleton({super.key, this.items = 3});

  final int items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var index = 0; index < items; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Row(
                    children: <Widget>[
                      ShimmerBone(width: 40, height: 40, radius: 12),
                      SizedBox(width: 10),
                      Expanded(child: ShimmerBone(height: 14)),
                      SizedBox(width: 10),
                      ShimmerBone(width: 46, height: 20, radius: 99),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const ShimmerBone(height: 12),
                  const SizedBox(height: 8),
                  ShimmerBone(
                    height: 12,
                    width: MediaQuery.sizeOf(context).width * 0.45,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class KeyValueRow extends StatelessWidget {
  const KeyValueRow({
    required this.label,
    required this.value,
    super.key,
    this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: context.mutedColor),
            const SizedBox(width: 7),
          ],
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.mutedColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox({
    required this.hint,
    required this.onChanged,
    super.key,
    this.controller,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 21),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(99),
          borderSide: BorderSide(color: context.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(99),
          borderSide: BorderSide(color: context.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(99),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.6,
          ),
        ),
      ),
    );
  }
}

/// ورقة اختيار من قائمة نصية مع بحث.
Future<String?> showOptionsSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _OptionsSheet(title: title, options: options),
  );
}

class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet({required this.title, required this.options});

  final String title;
  final List<String> options;

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = widget.options
        .where((option) => option.toLowerCase().contains(_query.toLowerCase()))
        .toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: Row(
                  children: <Widget>[
                    IconBadge(
                      icon: Icons.list_alt_rounded,
                      tone: theme.colorScheme.primary,
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: false,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'بحث...',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'لا توجد نتائج',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.mutedColor,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final option = filtered[index];
                          return ListTile(
                            title: Text(option),
                            trailing: const Icon(
                              Icons.chevron_left_rounded,
                              size: 18,
                            ),
                            onTap: () => Navigator.of(context).pop(option),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// يقرأ ترميز صورة POD إلى Widget.
class PodSignature extends StatelessWidget {
  const PodSignature({required this.dataUrl, super.key, this.height = 90});

  final String dataUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bytes = decodeDataUrl(dataUrl);
    if (bytes == null) {
      return Text(
        'بدون توقيع',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.mutedColor,
            ),
      );
    }
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.hairline),
      ),
      child: Image.memory(bytes, fit: BoxFit.contain),
    );
  }
}
