import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../expenses/presentation/controllers/expenses_controller.dart';
import '../../../expenses/presentation/controllers/personal_expenses_controller.dart';
import '../../../expenses/presentation/screens/budget_analytics_screen.dart';
import '../../../expenses/presentation/screens/personal_expenses_screen.dart';
import '../../../groups/presentation/controllers/groups_controller.dart';
import '../../../lists/domain/models/grocery_item.dart';
import '../../../lists/presentation/controllers/grocery_controller.dart';
import '../../../lists/presentation/screens/shopping_session_screen.dart';
import '../../../groups/presentation/widgets/room_switcher_title.dart';
import '../../../notifications/presentation/widgets/notification_bell_icon.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final activeGroup = ref.watch(activeGroupProvider);
    final itemsAsync = ref.watch(groceryItemsProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final personalExpensesAsync = ref.watch(personalExpensesStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const RoomSwitcherAppBarTitle(fallbackTitle: 'GrocEase'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Budget & Analytics',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BudgetAnalyticsScreen(),
                ),
              );
            },
          ),
          const NotificationBellIcon(),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${user?.displayName ?? "Shopper"} 👋',
                          style: AppTypography.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeGroup != null
                              ? 'Active Group: ${activeGroup.name}'
                              : 'Select or create a household group to start.',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  if (activeGroup != null)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.forest,
                        side: const BorderSide(color: AppColors.forest),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () => context.go('/groups'),
                      child: const Text('Switch'),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Live Stats Grid
              if (activeGroup != null) ...[
                Row(
                  children: [
                    // Pending Groceries Count
                    Expanded(
                      child: AppCard(
                        child: itemsAsync.when(
                          loading: () => const Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                          error: (_, __) => const Text('—'),
                          data: (items) {
                            final pending = items
                                .where((i) => i.status == GroceryStatus.pending)
                                .length;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.shopping_cart_outlined,
                                        size: 20, color: AppColors.forest),
                                    const SizedBox(width: 6),
                                    Text('To Buy',
                                        style: AppTypography.bodySmall),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$pending items',
                                  style: AppTypography.headlineMedium
                                      .copyWith(color: AppColors.forest),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Net Balance
                    Expanded(
                      child: AppCard(
                        child: paymentsAsync.when(
                          loading: () => const Center(
                            child: SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.forest,
                              ),
                            ),
                          ),
                          error: (_, __) => const Text('—'),
                          data: (payments) {
                            double owed = 0.0;
                            double owes = 0.0;
                            for (final p in payments.where((p) => p.isPending)) {
                              if (p.payeeUserId == user?.uid) owed += p.amount;
                              if (p.payerUserId == user?.uid) owes += p.amount;
                            }
                            final net = owed - owes;
                            final isPositive = net >= 0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isPositive
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      size: 20,
                                      color: isPositive
                                          ? AppColors.moss
                                          : AppColors.rust,
                                    ),
                                    const SizedBox(width: 6),
                                    Text('Net Balance',
                                        style: AppTypography.bodySmall),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${isPositive ? '+' : '-'}\$${net.abs().toStringAsFixed(2)}',
                                  style: AppTypography.headlineMedium.copyWith(
                                    color: isPositive
                                        ? AppColors.moss
                                        : AppColors.rust,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              // Quick Actions
              Text('Quick Actions', style: AppTypography.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppCard(
                      child: InkWell(
                        onTap: () {
                          if (activeGroup != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ShoppingSessionScreen(),
                              ),
                            );
                          } else {
                            context.go('/groups');
                          }
                        },
                        child: Column(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppColors.sage,
                              child: Icon(Icons.shopping_bag_outlined,
                                  color: AppColors.forest),
                            ),
                            const SizedBox(height: 8),
                            Text('Shop Mode', style: AppTypography.labelLarge),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      child: InkWell(
                        onTap: () => context.go('/expenses'),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppColors.sage,
                              child: Icon(Icons.document_scanner_outlined,
                                  color: AppColors.forest),
                            ),
                            const SizedBox(height: 8),
                            Text('Scan Bill', style: AppTypography.labelLarge),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppCard(
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PersonalExpensesScreen(),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppColors.sage,
                              child: Icon(Icons.receipt_long,
                                  color: AppColors.forest),
                            ),
                            const SizedBox(height: 8),
                            Text('Personal', style: AppTypography.labelLarge),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Groceries Preview
              Text('Shared Grocery Basket', style: AppTypography.titleLarge),
              const SizedBox(height: 12),
              itemsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.forest),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (items) {
                  final pending = items
                      .where((i) => i.status == GroceryStatus.pending)
                      .take(4)
                      .toList();

                  if (pending.isEmpty) {
                    return AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: AppColors.moss),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                activeGroup == null
                                    ? 'Join a group to share lists.'
                                    : 'Basket is all clear! Add items in Lists.',
                                style: AppTypography.bodyMedium,
                              ),
                            ),
                            if (activeGroup != null)
                              TextButton(
                                onPressed: () => context.go('/lists'),
                                child: const Text('Go to List'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      ...pending.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  Icons.circle_outlined,
                                  color: AppColors.forest,
                                  size: 18,
                                ),
                                title: Text(item.itemName,
                                    style: AppTypography.bodyLarge),
                                trailing: Text(
                                  'Qty: ${item.quantity}',
                                  style: AppTypography.bodySmall,
                                ),
                              ),
                            ),
                          )),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('View All in Lists'),
                          onPressed: () => context.go('/lists'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // Monthly Spending Snapshot
              Text('Personal Spending Snapshot',
                  style: AppTypography.titleLarge),
              const SizedBox(height: 12),
              personalExpensesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.forest),
                ),
                error: (e, _) => const SizedBox.shrink(),
                data: (expenses) {
                  final now = DateTime.now();
                  final thisMonth = expenses.where((e) =>
                      e.expenseDate.year == now.year &&
                      e.expenseDate.month == now.month);
                  final total =
                      thisMonth.fold<double>(0.0, (sum, e) => sum + e.amount);

                  return AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.sage,
                        child: Icon(Icons.wallet, color: AppColors.forest),
                      ),
                      title: const Text('Monthly Spending Total'),
                      subtitle: Text(
                        '${thisMonth.length} transactions recorded this month',
                        style: AppTypography.bodySmall,
                      ),
                      trailing: Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: AppTypography.titleLarge
                            .copyWith(color: AppColors.forest),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const BudgetAnalyticsScreen(),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
