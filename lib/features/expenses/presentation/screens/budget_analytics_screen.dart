import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../domain/models/budget.dart';
import '../../domain/models/personal_expense.dart';
import '../controllers/personal_expenses_controller.dart';
import 'personal_expenses_screen.dart';

class BudgetAnalyticsScreen extends ConsumerStatefulWidget {
  const BudgetAnalyticsScreen({super.key});

  @override
  ConsumerState<BudgetAnalyticsScreen> createState() =>
      _BudgetAnalyticsScreenState();
}

class _BudgetAnalyticsScreenState
    extends ConsumerState<BudgetAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final expensesAsync = ref.watch(personalExpensesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Budget & Analytics'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.forest,
          unselectedLabelColor: AppColors.inkMuted,
          indicatorColor: AppColors.forest,
          tabs: const [
            Tab(text: 'Budgets'),
            Tab(text: 'Categories'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: budgetsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.forest),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (budgets) {
          return expensesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (expenses) {
              return TabBarView(
                controller: _tabController,
                children: [
                  _BudgetOverviewTab(budgets: budgets, expenses: expenses),
                  _CategoryBreakdownTab(expenses: expenses),
                  _SpendingHistoryTab(expenses: expenses),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Tab 1: Budget Overview ───────────────────────────────────────────────────

class _BudgetOverviewTab extends ConsumerWidget {
  const _BudgetOverviewTab({
    required this.budgets,
    required this.expenses,
  });

  final List<Budget> budgets;
  final List<PersonalExpense> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final currentMonthExpenses = expenses.where((e) =>
        e.expenseDate.year == now.year && e.expenseDate.month == now.month);

    final spendByCategory = <String, double>{};
    for (final exp in currentMonthExpenses) {
      final cat = exp.category;
      spendByCategory[cat] = (spendByCategory[cat] ?? 0.0) + exp.amount;
    }

    final totalBudget =
        budgets.fold<double>(0.0, (sum, b) => sum + b.monthlyLimit);
    final totalSpent = currentMonthExpenses.fold<double>(
        0.0, (sum, e) => sum + e.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overall Budget Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Monthly Budget', style: AppTypography.titleLarge),
                  Text(
                    '\$${totalSpent.toStringAsFixed(2)} / \$${totalBudget.toStringAsFixed(2)}',
                    style: AppTypography.titleLarge
                        .copyWith(color: AppColors.forest),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0,
                  minHeight: 10,
                  backgroundColor: AppColors.line,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    totalSpent > totalBudget ? AppColors.rust : AppColors.forest,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    totalSpent > totalBudget
                        ? 'Over budget by \$${(totalSpent - totalBudget).toStringAsFixed(2)}'
                        : '\$${(totalBudget - totalSpent).toStringAsFixed(2)} remaining',
                    style: AppTypography.bodySmall.copyWith(
                      color: totalSpent > totalBudget
                          ? AppColors.rust
                          : AppColors.forest,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Set Budget'),
                    onPressed: () => _showSetBudgetDialog(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Text('Category Budgets', style: AppTypography.titleLarge),
        const SizedBox(height: 12),

        if (budgets.isEmpty)
          AppEmptyState(
            icon: Icons.pie_chart_outline,
            title: 'No category budgets set',
            description: 'Set monthly budget limits to track spending by category.',
            actionLabel: 'Set Budget',
            onActionPressed: () => _showSetBudgetDialog(context, ref),
          )
        else
          ...budgets.map((b) {
            final spent = spendByCategory[b.category] ?? 0.0;
            final usage = BudgetUsage.compute(
              category: b.category,
              limit: b.monthlyLimit,
              spent: spent,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(b.category, style: AppTypography.bodyLarge),
                        Text(
                          '\$${spent.toStringAsFixed(2)} / \$${b.monthlyLimit.toStringAsFixed(2)}',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: usage.exceeded
                                ? AppColors.rust
                                : AppColors.forest,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (usage.percentageUsed / 100.0).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: AppColors.line,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          usage.exceeded
                              ? AppColors.rust
                              : (usage.percentageUsed > 80
                                  ? AppColors.gold
                                  : AppColors.moss),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          usage.exceeded
                              ? '⚠️ Exceeded by \$${(spent - b.monthlyLimit).toStringAsFixed(2)}'
                              : '\$${usage.remaining.toStringAsFixed(2)} remaining (${usage.percentageUsed.toStringAsFixed(0)}%)',
                          style: AppTypography.bodySmall.copyWith(
                            color: usage.exceeded ? AppColors.rust : AppColors.inkMuted,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rust),
                          onPressed: () => ref
                              .read(personalExpensesControllerProvider.notifier)
                              .deleteBudget(b.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showSetBudgetDialog(BuildContext context, WidgetRef ref) {
    final limitCtrl = TextEditingController();
    String category = kExpenseCategories.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.paper,
          title: Text('Set Category Budget', style: AppTypography.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: kExpenseCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setStateDialog(() => category = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: limitCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Monthly Limit (\$)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.forest),
              onPressed: () async {
                final limit = double.tryParse(limitCtrl.text.trim()) ?? 0.0;
                if (limit <= 0) return;

                Navigator.of(ctx).pop();
                await ref
                    .read(personalExpensesControllerProvider.notifier)
                    .setBudget(category: category, monthlyLimit: limit);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 2: Category Breakdown (Pie Chart) ────────────────────────────────────

class _CategoryBreakdownTab extends StatelessWidget {
  const _CategoryBreakdownTab({required this.expenses});

  final List<PersonalExpense> expenses;

  static const List<Color> _palette = [
    Color(0xFF2E6F40),
    Color(0xFF38A169),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
    Color(0xFF0D9488),
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonthExpenses = expenses.where((e) =>
        e.expenseDate.year == now.year && e.expenseDate.month == now.month);

    final totals = <String, double>{};
    for (final exp in currentMonthExpenses) {
      totals[exp.category] = (totals[exp.category] ?? 0.0) + exp.amount;
    }

    final totalSpent = totals.values.fold<double>(0.0, (sum, val) => sum + val);

    if (totals.isEmpty || totalSpent <= 0) {
      return const AppEmptyState(
        icon: Icons.pie_chart_outline,
        title: 'No spending this month',
        description: 'Add expenses to see a category-by-category breakdown.',
      );
    }

    final entries = totals.entries.toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Monthly Category Breakdown', style: AppTypography.titleLarge),
        const SizedBox(height: 20),

        // Pie Chart
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(entries.length, (i) {
                final entry = entries[i];
                final pct = (entry.value / totalSpent) * 100;
                final color = _palette[i % _palette.length];
                return PieChartSectionData(
                  color: color,
                  value: entry.value,
                  title: '${pct.toStringAsFixed(0)}%',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),

        const SizedBox(height: 24),
        ...List.generate(entries.length, (i) {
          final entry = entries[i];
          final color = _palette[i % _palette.length];
          final pct = (entry.value / totalSpent) * 100;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(entry.key, style: AppTypography.bodyLarge),
                  ),
                  Text(
                    '\$${entry.value.toStringAsFixed(2)} (${pct.toStringAsFixed(1)}%)',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─── Tab 3: Spending History (Bar Chart) ──────────────────────────────────────

class _SpendingHistoryTab extends StatelessWidget {
  const _SpendingHistoryTab({required this.expenses});

  final List<PersonalExpense> expenses;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Group last 6 months
    final monthTotals = <String, double>{};
    final monthLabels = <String>[];

    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
      monthTotals[key] = 0.0;
      monthLabels.add('${_monthName(date.month)} ${date.year % 100}');
    }

    for (final exp in expenses) {
      final key =
          '${exp.expenseDate.year}-${exp.expenseDate.month.toString().padLeft(2, '0')}';
      if (monthTotals.containsKey(key)) {
        monthTotals[key] = monthTotals[key]! + exp.amount;
      }
    }

    final barGroups = <BarChartGroupData>[];
    final values = monthTotals.values.toList();
    double maxY = 100.0;

    for (int i = 0; i < values.length; i++) {
      final val = values[i];
      if (val > maxY) maxY = val * 1.2;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: i == values.length - 1 ? AppColors.forest : AppColors.moss,
              width: 18,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Monthly Spending (Last 6 Months)', style: AppTypography.titleLarge),
        const SizedBox(height: 24),

        SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              barGroups: barGroups,
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < monthLabels.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            monthLabels[idx],
                            style: AppTypography.bodySmall.copyWith(fontSize: 10),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(drawVerticalLine: false),
            ),
          ),
        ),

        const SizedBox(height: 24),
        ...List.generate(monthLabels.length, (i) {
          final label = monthLabels[i];
          final val = values[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: AppTypography.bodyMedium),
                  Text(
                    '\$${val.toStringAsFixed(2)}',
                    style: AppTypography.titleLarge.copyWith(color: AppColors.forest),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  static String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return names[month - 1];
  }
}
