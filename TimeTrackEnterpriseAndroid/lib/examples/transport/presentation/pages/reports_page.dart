import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/report_data.dart';
import '../providers/transport_providers.dart';
import '../widgets/transport_format.dart';
import '../widgets/transport_widgets.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportPeriod _period = ReportPeriod.month;

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(reportDataProvider(_period));

    return Scaffold(
      body: Column(
        children: <Widget>[
          PageHero(
            title: 'التقارير',
            subtitle: 'التحصيل والمصروفات وأعلى العملاء',
            actions: <Widget>[
              HeroIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'تحديث',
                onTap: () {
                  ref.invalidate(shipmentsProvider);
                  ref.invalidate(paymentsProvider);
                  ref.invalidate(expensesProvider);
                },
              ),
            ],
          ),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: ErrorState(
                  error: error,
                  onRetry: () {
                    ref.invalidate(shipmentsProvider);
                    ref.invalidate(paymentsProvider);
                    ref.invalidate(expensesProvider);
                  },
                ),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(shipmentsProvider);
                  ref.invalidate(paymentsProvider);
                  ref.invalidate(expensesProvider);
                  await ref.read(reportDataProvider(_period).future);
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: <Widget>[
                    if (data.fromCache) ...<Widget>[
                      const CachedBanner(),
                      const SizedBox(height: 12),
                    ],
                    _PeriodSelector(
                      period: _period,
                      onChanged: (value) => setState(() => _period = value),
                    ),
                    const SizedBox(height: 14),
                    _KpiGrid(report: data.value, period: _period),
                    const SizedBox(height: 14),
                    SectionCard(
                      title: 'حركة الإيرادات',
                      subtitle:
                          'التحصيل اليومي/الأسبوعي من ${formatDate(data.value.start)} '
                          'إلى ${formatDate(data.value.end)}',
                      icon: Icons.insert_chart_outlined_rounded,
                      child: _RevenueChart(points: data.value.revenueTimeline),
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      title: 'الإيرادات حسب طريقة الدفع',
                      icon: Icons.account_balance_wallet_outlined,
                      child: _MethodBreakdown(
                        values: data.value.revenueByMethod,
                        total: data.value.revenue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      title: 'توزيع الشحنات حسب الحالة',
                      subtitle:
                          '${data.value.shipmentsCount} شحنة مسجّلة داخل الفترة المحددة',
                      icon: Icons.pie_chart_outline_rounded,
                      child: _StatusBreakdown(
                        values: data.value.shipmentsByStatus,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SectionCard(
                      title: 'أعلى العملاء',
                      subtitle: 'الترتيب حسب إجمالي أجرة الشحنات في الفترة',
                      icon: Icons.workspace_premium_outlined,
                      child: _TopCustomers(customers: data.value.topCustomers),
                    ),
                    const SizedBox(height: 12),
                    _NoteCard(period: _period),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.period, required this.onChanged});

  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'الفترة',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final option in ReportPeriod.values)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    label: Text(option.label),
                    selected: option == period,
                    onSelected: (_) => onChanged(option),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.report, required this.period});

  final ReportData report;
  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final average = report.shipmentsCount == 0
        ? 0.0
        : report.revenue / report.shipmentsCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'إجمالي التحصيل',
                value: formatMoney(report.revenue),
                icon: Icons.payments_rounded,
                tone: const Color(0xFF17795E),
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'المصروفات',
                value: formatMoney(report.expenses),
                icon: Icons.trending_down_rounded,
                tone: const Color(0xFFB3741A),
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'الصافي',
                value: formatMoney(report.net),
                icon: Icons.savings_outlined,
                tone: report.net >= 0
                    ? const Color(0xFF1E5FA8)
                    : Theme.of(context).colorScheme.error,
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'مستحقات مفتوحة',
                value: formatMoney(report.openDue),
                icon: Icons.receipt_long_outlined,
                tone: const Color(0xFF6B5B95),
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'شحنات الفترة',
                value: formatNumber(report.shipmentsCount),
                icon: Icons.inventory_2_outlined,
                tone: const Color(0xFF3F5F8F),
                hint: 'متوسط ${formatMoney(average)} للشحنة',
              ),
            ),
            SizedBox(
              width: width,
              child: MetricTile(
                label: 'شحنات مكتملة',
                value: formatNumber(report.completedCount),
                icon: Icons.task_alt_rounded,
                tone: const Color(0xFF17795E),
                hint: 'أجورها ${formatMoney(report.completedFees)}',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.points});

  final List<RevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.isEmpty) {
      return const EmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'لا توجد بيانات للفترة',
        subtitle: 'ستظهر حركة التحصيل هنا بعد تسجيل دفعات.',
      );
    }

    var maxValue = 0.0;
    for (final point in points) {
      if (point.amount > maxValue) maxValue = point.amount;
    }
    if (maxValue <= 0) {
      return EmptyState(
        icon: Icons.bar_chart_rounded,
        title: 'لا توجد تحصيلات في هذه الفترة',
        subtitle: 'الإجمالي المحصّل صفر. جرّب فترة أطول.',
        action: Text(
          'الفترة تحتوي ${points.length} نقطة زمنية',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 150,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gap = points.length > 14 ? 2.0 : 4.0;
              final barWidth =
                  (constraints.maxWidth - gap * (points.length - 1)) /
                      points.length;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (var index = 0; index < points.length; index++)
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: index == points.length - 1 ? 0 : gap,
                      ),
                      child: SizedBox(
                        width: barWidth < 3 ? 3 : barWidth,
                        child: Tooltip(
                          message: '${points[index].label}: '
                              '${formatMoney(points[index].amount)}',
                          child: Container(
                            height: 24 +
                                (maxValue <= 0
                                    ? 0
                                    : (points[index].amount / maxValue) * 110),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: <Color>[
                                  theme.colorScheme.primary.withValues(
                                    alpha: 0.85,
                                  ),
                                  theme.colorScheme.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                ],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Text(
              points.first.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              'الذروة ${formatMoney(maxValue)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              points.last.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MethodBreakdown extends StatelessWidget {
  const _MethodBreakdown({required this.values, required this.total});

  final Map<String, double> values;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final active = entries.where((entry) => entry.value > 0).toList();

    if (active.isEmpty) {
      return const EmptyState(
        icon: Icons.wallet_outlined,
        title: 'لا توجد دفعات مسجّلة',
        subtitle: 'ستظهر طرق الدفع بعد تسجيل أول سند قبض.',
      );
    }

    return Column(
      children: <Widget>[
        for (final entry in active)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.circle,
                      size: 9,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      formatMoney(entry.value),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 46,
                      child: Text(
                        total <= 0
                            ? '0%'
                            : '${formatNumber(entry.value / total * 100)}%',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: total <= 0
                        ? 0
                        : (entry.value / total).clamp(0, 1).toDouble(),
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.values});

  final Map<String, int> values;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return const EmptyState(
        icon: Icons.pie_chart_outline_rounded,
        title: 'لا توجد شحنات',
        subtitle: 'لم تُسجّل شحنات داخل الفترة المحددة.',
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final entry in entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor(context, entry.key).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor(context, entry.key),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  formatNumber(entry.value),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: statusColor(context, entry.key),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TopCustomers extends StatelessWidget {
  const _TopCustomers({required this.customers});

  final List<CustomerTotal> customers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (customers.isEmpty) {
      return const EmptyState(
        icon: Icons.workspace_premium_outlined,
        title: 'لا توجد بيانات عملاء',
        subtitle: 'ستظهر أعلى العملاء بعد تسجيل شحنات في الفترة.',
      );
    }

    return Column(
      children: <Widget>[
        for (var index = 0; index < customers.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? const Color(0xFFB3741A).withValues(alpha: 0.14)
                        : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: index == 0
                          ? const Color(0xFF8A5A12)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        customers[index].name.isEmpty
                            ? 'عميل غير مسمى'
                            : customers[index].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${customers[index].shipments} شحنة',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatMoney(customers[index].total),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.period});

  final ReportPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.info_outline_rounded, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'تُحسب هذه الأرقام على الجهاز من سندات القبض والمصروفات '
                'والشحنات المحمّلة من الخادم خلال «${period.label}». '
                'المستحقات المفتوحة تشمل كل الشحنات غير المسددة وليست '
                'محصورة بالفترة.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
