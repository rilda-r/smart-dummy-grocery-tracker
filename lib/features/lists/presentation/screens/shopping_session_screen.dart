import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../groups/presentation/controllers/groups_controller.dart';
import '../../domain/models/grocery_item.dart';
import '../controllers/grocery_controller.dart';

/// Shopping mode screen — presented as a full-page route from the Lists screen.
class ShoppingSessionScreen extends ConsumerStatefulWidget {
  const ShoppingSessionScreen({super.key});

  @override
  ConsumerState<ShoppingSessionScreen> createState() =>
      _ShoppingSessionScreenState();
}

class _ShoppingSessionScreenState
    extends ConsumerState<ShoppingSessionScreen> {
  bool _showSummary = false;

  @override
  Widget build(BuildContext context) {
    final activeGroup = ref.watch(activeGroupProvider);
    final currentUser = ref.watch(currentUserProvider);
    final itemsAsync = ref.watch(groceryItemsProvider);

    if (activeGroup == null) {
      return const Scaffold(
        backgroundColor: AppColors.paper,
        body: Center(child: Text('No group selected.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Shopping Mode'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.forest),
            label: Text(
              'Spend',
              style: AppTypography.labelLarge.copyWith(color: AppColors.forest),
            ),
            onPressed: () {
              final items = itemsAsync.valueOrNull ?? [];
              final purchased = items.where((i) => i.status == GroceryStatus.purchased).toList();
              Navigator.of(context).pop();
              context.go('/expenses?upload=true', extra: purchased);
            },
          ),
          TextButton(
            onPressed: () => setState(() => _showSummary = true),
            child: Text(
              'Summary',
              style: AppTypography.labelLarge.copyWith(color: AppColors.forest),
            ),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.forest),
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          final pending =
              items.where((i) => i.status == GroceryStatus.pending).toList();
          final purchased =
              items.where((i) => i.status == GroceryStatus.purchased).toList();
          final unavailable =
              items.where((i) => i.status == GroceryStatus.unavailable).toList();

          if (_showSummary || (pending.isEmpty && (purchased.isNotEmpty || unavailable.isNotEmpty))) {
            return _ShoppingSummary(
              purchased: purchased,
              unavailable: unavailable,
              pending: pending,
              onContinue: () => setState(() => _showSummary = false),
            );
          }

          if (pending.isEmpty) {
            return const AppEmptyState(
              icon: Icons.check_circle_outline,
              title: 'All done!',
              description: 'All grocery items have been handled.',
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.forest, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tap an item to lock it for buying, then mark as purchased or unavailable.',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.forest),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...pending.map((item) => _ShoppingItemTile(
                    item: item,
                    currentUserId: currentUser?.uid ?? '',
                  )),
            ],
          );
        },
      ),
    );
  }
}

// ─── Shopping Item Tile ───────────────────────────────────────────────────────

class _ShoppingItemTile extends ConsumerWidget {
  const _ShoppingItemTile({
    required this.item,
    required this.currentUserId,
  });

  final GroceryItem item;
  final String currentUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final isLocked = item.isLocked && !item.isLockStale(now);
    final isLockedByMe = item.lockedBy == currentUserId;
    final isLockedByOther = isLocked && !isLockedByMe;

    Color cardBorder = AppColors.line;
    if (isLockedByMe) cardBorder = AppColors.forest;
    if (isLockedByOther) cardBorder = AppColors.gold;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        borderColor: cardBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.itemName, style: AppTypography.bodyLarge),
                      Text('Need: ${item.quantity}',
                          style: AppTypography.bodySmall),
                    ],
                  ),
                ),
                if (isLockedByOther)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Being bought',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.gold),
                    ),
                  ),
              ],
            ),

            if (!isLockedByOther) ...[
              const SizedBox(height: 12),
              if (!isLockedByMe)
                AppButton(
                  text: 'I\'ll buy this',
                  isFullWidth: false,
                  icon: const Icon(Icons.shopping_cart_outlined,
                      color: Colors.white, size: 16),
                  onPressed: () async {
                    final ok = await ref
                        .read(groceryControllerProvider.notifier)
                        .lockItem(item.id);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ref
                                    .read(groceryControllerProvider)
                                    .error
                                    ?.toString() ??
                                'Could not lock item.',
                          ),
                          backgroundColor: AppColors.rust,
                        ),
                      );
                    }
                  },
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'Purchased',
                        variant: AppButtonVariant.primary,
                        onPressed: () => _markPurchased(context, ref),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        text: 'Unavailable',
                        variant: AppButtonVariant.secondary,
                        onPressed: () async {
                          await ref
                              .read(groceryControllerProvider.notifier)
                              .updateStatus(
                                itemId: item.id,
                                newStatus: GroceryStatus.unavailable,
                              );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.undo, color: AppColors.inkMuted),
                      tooltip: 'Release lock',
                      onPressed: () async {
                        await ref
                            .read(groceryControllerProvider.notifier)
                            .releaseItemLock(item.id);
                      },
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  void _markPurchased(BuildContext context, WidgetRef ref) {
    final qtyCtrl =
        TextEditingController(text: item.quantity.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('How many did you buy?',
            style: AppTypography.titleLarge),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration:
              const InputDecoration(labelText: 'Quantity purchased'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forest),
            onPressed: () async {
              final qty =
                  int.tryParse(qtyCtrl.text.trim()) ?? item.quantity;
              Navigator.of(ctx).pop();
              await ref
                  .read(groceryControllerProvider.notifier)
                  .updateStatus(
                    itemId: item.id,
                    newStatus: GroceryStatus.purchased,
                    purchasedQuantity: qty,
                  );
            },
            child: const Text('Confirm',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Shopping Summary ─────────────────────────────────────────────────────────

class _ShoppingSummary extends StatelessWidget {
  const _ShoppingSummary({
    required this.purchased,
    required this.unavailable,
    required this.pending,
    required this.onContinue,
  });

  final List<GroceryItem> purchased;
  final List<GroceryItem> unavailable;
  final List<GroceryItem> pending;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Shopping Summary', style: AppTypography.headlineMedium),
        const SizedBox(height: 16),

        _SummarySection(
          title: '✅ Purchased (${purchased.length})',
          items: purchased,
          color: AppColors.moss,
        ),
        _SummarySection(
          title: '❌ Unavailable (${unavailable.length})',
          items: unavailable,
          color: AppColors.rust,
        ),
        _SummarySection(
          title: '⏳ Still Pending (${pending.length})',
          items: pending,
          color: AppColors.gold,
        ),

        const SizedBox(height: 24),
        AppButton(
          text: 'Upload Bill & Split in Spend',
          variant: AppButtonVariant.primary,
          icon: const Icon(Icons.receipt_long, color: Colors.white, size: 18),
          onPressed: () {
            Navigator.of(context).pop();
            context.go('/expenses?upload=true', extra: purchased);
          },
        ),
        const SizedBox(height: 12),
        if (pending.isNotEmpty)
          AppButton(
            text: 'Continue Shopping',
            variant: AppButtonVariant.secondary,
            onPressed: onContinue,
          )
        else
          AppButton(
            text: 'Done — Close',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.items,
    required this.color,
  });

  final String title;
  final List<GroceryItem> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: AppTypography.titleLarge.copyWith(color: color)),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                      child: Text(item.itemName,
                          style: AppTypography.bodyMedium)),
                  Text(
                    item.status == GroceryStatus.purchased
                        ? 'Got ${item.purchasedQuantity} / ${item.quantity}'
                        : 'Need ${item.quantity}',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            )),
        const SizedBox(height: 16),
      ],
    );
  }
}
