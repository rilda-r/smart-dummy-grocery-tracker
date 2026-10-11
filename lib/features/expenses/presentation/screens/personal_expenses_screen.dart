import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../controllers/personal_expenses_controller.dart';

const List<String> kExpenseCategories = [
  'Groceries',
  'Dining',
  'Rent',
  'Utilities',
  'Transport',
  'Entertainment',
  'Health',
  'Other',
];

class PersonalExpensesScreen extends ConsumerStatefulWidget {
  const PersonalExpensesScreen({super.key});

  @override
  ConsumerState<PersonalExpensesScreen> createState() =>
      _PersonalExpensesScreenState();
}

class _PersonalExpensesScreenState
    extends ConsumerState<PersonalExpensesScreen> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(personalExpensesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Personal Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Expense',
            onPressed: () => _showAddExpenseDialog(context),
          ),
        ],
      ),
      body: expensesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.forest),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) {
          final now = DateTime.now();
          final currentMonthExpenses = expenses.where((e) =>
              e.expenseDate.year == now.year &&
              e.expenseDate.month == now.month);
          final currentMonthTotal = currentMonthExpenses.fold<double>(
              0.0, (sum, e) => sum + e.amount);

          final filtered = _selectedCategory == 'All'
              ? expenses
              : expenses
                  .where((e) =>
                      e.category.toLowerCase() ==
                      _selectedCategory.toLowerCase())
                  .toList();

          return Column(
            children: [
              // Monthly spend banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spent this month',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.inkMuted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${currentMonthTotal.toStringAsFixed(2)}',
                          style: AppTypography.headlineMedium
                              .copyWith(color: AppColors.forest),
                        ),
                      ],
                    ),
                    AppButton(
                      text: '+ Add',
                      isFullWidth: false,
                      onPressed: () => _showAddExpenseDialog(context),
                    ),
                  ],
                ),
              ),

              // Category filter pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _selectedCategory == 'All',
                      onSelected: () =>
                          setState(() => _selectedCategory = 'All'),
                    ),
                    ...kExpenseCategories.map((cat) => _FilterChip(
                          label: cat,
                          isSelected: _selectedCategory == cat,
                          onSelected: () =>
                              setState(() => _selectedCategory = cat),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // List of expenses
              Expanded(
                child: filtered.isEmpty
                    ? AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No expenses found',
                        description: _selectedCategory == 'All'
                            ? 'Tap "+ Add" to track your personal spending.'
                            : 'No expenses under $_selectedCategory.',
                        actionLabel: 'Add Expense',
                        onActionPressed: () => _showAddExpenseDialog(context),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final expense = filtered[index];
                          return AppCard(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.sage,
                                child: Icon(
                                  _categoryIcon(expense.category),
                                  color: AppColors.forest,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                expense.description?.isNotEmpty == true
                                    ? expense.description!
                                    : expense.category,
                                style: AppTypography.bodyLarge,
                              ),
                              subtitle: Text(
                                '${expense.category} • ${expense.expenseDate.toLocal().toString().split(' ')[0]}',
                                style: AppTypography.bodySmall,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '\$${expense.amount.toStringAsFixed(2)}',
                                    style: AppTypography.titleLarge
                                        .copyWith(color: AppColors.forest),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: AppColors.rust),
                                    onPressed: () => ref
                                        .read(
                                            personalExpensesControllerProvider
                                                .notifier)
                                        .deleteExpense(expense.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = kExpenseCategories.first;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.paper,
          title: Text('Add Personal Expense', style: AppTypography.titleLarge),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (\$)'),
                ),
                const SizedBox(height: 12),
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
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.forest),
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amount <= 0) return;

                Navigator.of(ctx).pop();
                await ref
                    .read(personalExpensesControllerProvider.notifier)
                    .addExpense(
                      amount: amount,
                      category: category,
                      expenseDate: selectedDate,
                      description: descCtrl.text.trim().isEmpty
                          ? null
                          : descCtrl.text.trim(),
                    );
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'groceries':
        return Icons.shopping_basket_outlined;
      case 'dining':
        return Icons.restaurant_outlined;
      case 'rent':
        return Icons.home_outlined;
      case 'utilities':
        return Icons.bolt_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      default:
        return Icons.payment_outlined;
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.sage,
        checkmarkColor: AppColors.forest,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.forest : AppColors.ink,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
