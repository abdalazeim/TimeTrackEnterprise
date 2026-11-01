import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/i18n/app_locale.dart';
import '../../../../app/i18n/app_strings.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/sync/sync_overview.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/home_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final auth = ref.watch(authControllerProvider);
    final overview = ref.watch(syncOverviewProvider);
    final username = auth.user?.username ?? (strings.isArabic ? 'مستخدم' : 'User');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(syncOverviewProvider);
          try {
            await ref.read(syncOverviewProvider.future);
          } catch (_) {
            // The screen shows the failure state and keeps its retry action.
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: HeroHeader(
                leading: AppLogo(
                  size: 46,
                  showShadow: false,
                  background: Colors.white.withValues(alpha: 0.14),
                ),
                title: AppConfig.appName,
                subtitle: strings.hello(username),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    HeroIconButton(
                      icon: Icons.translate_rounded,
                      tooltip: strings.languageSwitch,
                      onTap: () => toggleAppLocale(ref),
                    ),
                    const SizedBox(width: 4),
                    HeroIconButton(
                      icon: Icons.logout_rounded,
                      tooltip: strings.logout,
                      onTap: () => _confirmLogout(context, ref, strings),
                    ),
                  ],
                ),
                child: overview.maybeWhen(
                  data: (data) => Row(
                    children: <Widget>[
                      Expanded(
                        child: StatPill(
                          label: strings.waiting,
                          value: '${data.waiting + data.inFlight}',
                          icon: Icons.schedule_rounded,
                          onDark: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatPill(
                          label: strings.attention,
                          value: '${data.needsAttention}',
                          icon: Icons.report_problem_outlined,
                          onDark: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatPill(
                          label: strings.savedRecords,
                          value: '${data.cachedRecords}',
                          icon: Icons.storage_rounded,
                          onDark: true,
                        ),
                      ),
                    ],
                  ),
                  orElse: () => const SizedBox(height: 58),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  SectionHeader(
                    title: strings.quickStart,
                    subtitle: strings.quickStartHint,
                    icon: Icons.rocket_launch_outlined,
                  ),
                  AppCard(
                    onTap: () => context.push(Routes.exampleItems),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        const IconBadge(
                          icon: Icons.dataset_outlined,
                          tone: AppColors.info,
                          size: 46,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                strings.exampleRecords,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                strings.exampleRecordsHint,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    onTap: () => context.push(Routes.gateway),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: <Widget>[
                        const IconBadge(
                          icon: Icons.router_rounded,
                          tone: AppColors.success,
                          size: 46,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                strings.gatewayTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                strings.gatewaySubtitle,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  SectionHeader(
                    title: strings.syncTitle,
                    subtitle: strings.syncHint,
                    icon: Icons.sync_rounded,
                    action: TextButton(
                      onPressed: () => ref.invalidate(syncOverviewProvider),
                      child: Text(strings.refresh),
                    ),
                  ),
                  overview.when(
                    loading: () => const AppCard(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => AppCard(
                      child: Column(
                        children: <Widget>[
                          Text('${strings.loadFailed}: $error'),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(syncOverviewProvider),
                            child: Text(strings.retry),
                          ),
                        ],
                      ),
                    ),
                    data: (data) => _SyncSummary(
                      overview: data,
                      strings: strings,
                    ),
                  ),
                  if (auth.isSubmitting) ...<Widget>[
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.logout),
        content: Text(strings.logoutPrompt),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

class _SyncSummary extends StatelessWidget {
  const _SyncSummary({required this.overview, required this.strings});

  final SyncOverview overview;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              _Metric(label: strings.waiting, value: overview.waiting.toString()),
              _Metric(label: strings.attention, value: overview.needsAttention.toString()),
              _Metric(label: strings.savedRecords, value: overview.cachedRecords.toString()),
            ],
          ),
          const Divider(height: 24),
          _DetailRow(label: strings.deviceId, value: overview.deviceId),
          const SizedBox(height: 8),
          _DetailRow(
            label: strings.lastSync,
            value: strings.lastSynced(overview.lastSyncAt),
          ),
          if (overview.lastStatus?.isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 8),
            _DetailRow(label: strings.lastResult, value: overview.lastStatus!),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
