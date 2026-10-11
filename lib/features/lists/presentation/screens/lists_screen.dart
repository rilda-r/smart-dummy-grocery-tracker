import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../groups/presentation/controllers/groups_controller.dart';
import '../../data/repositories/grocery_repository.dart';
import '../../domain/models/grocery_item.dart';
import '../controllers/grocery_controller.dart';
import 'shopping_session_screen.dart';

class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddItemSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddItemSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeGroup = ref.watch(activeGroupProvider);
    final itemsAsync = ref.watch(groceryItemsProvider);
    final controllerState = ref.watch(groceryControllerProvider);

    // Listen for errors from controller
    ref.listen<AsyncValue<void>>(groceryControllerProvider, (_, next) {
      next.whenOrNull(
        error: (e, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.rust,
            ),
          );
        },
      );
    });

    if (activeGroup == null) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          title: const Text('Shared Lists'),
        ),
        body: AppEmptyState(
          icon: Icons.group_outlined,
          title: 'No group selected',
          description: 'Join or create a group to start sharing a grocery list.',
          actionLabel: 'Go to Groups',
          onActionPressed: () => context.go('/groups'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Grocery List'),
            Text(
              activeGroup.name,
              style: AppTypography.bodySmall.copyWith(color: AppColors.moss),
            ),
          ],
        ),
        actions: [
          if (controllerState.isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.forest),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.forest),
            tooltip: 'Add item',
            onPressed: () => _showAddItemSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.forest,
          labelColor: AppColors.forest,
          unselectedLabelColor: AppColors.inkMuted,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Done'),
          ],
        ),
      ),
      body: itemsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.forest),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading list: $e',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.rust)),
          ),
        ),
        data: (items) {
          final pending =
              items.where((i) => i.status == GroceryStatus.pending).toList();
          final done = items
              .where((i) =>
                  i.status == GroceryStatus.purchased ||
                  i.status == GroceryStatus.unavailable)
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _ItemList(
                items: pending,
                emptyTitle: 'List is empty',
                emptyDescription:
                    'Tap the + button to add items to the shared list.',
                onAdd: () => _showAddItemSheet(context),
              ),
              _ItemList(
                items: done,
                emptyTitle: 'Nothing done yet',
                emptyDescription: 'Items marked as purchased or unavailable will appear here.',
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.forest,
        icon: const Icon(Icons.shopping_cart, color: Colors.white),
        label: Text('Shop Mode',
            style: AppTypography.labelLarge.copyWith(color: Colors.white)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ShoppingSessionScreen(),
            ),
          );
        },
      ),
    );
  }
}


// ─── Item List ────────────────────────────────────────────────────────────────

class _ItemList extends ConsumerWidget {
  const _ItemList({
    required this.items,
    required this.emptyTitle,
    required this.emptyDescription,
    this.onAdd,
  });

  final List<GroceryItem> items;
  final String emptyTitle;
  final String emptyDescription;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return AppEmptyState(
        icon: Icons.checklist_outlined,
        title: emptyTitle,
        description: emptyDescription,
        actionLabel: onAdd != null ? 'Add Item' : null,
        onActionPressed: onAdd,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _GroceryItemTile(item: items[index]);
      },
    );
  }
}

// ─── Item Tile ────────────────────────────────────────────────────────────────

class _GroceryItemTile extends ConsumerWidget {
  const _GroceryItemTile({required this.item});

  final GroceryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final isOwner = currentUser?.uid == item.addedBy;
    final now = DateTime.now();
    final isLocked = item.isLocked && !item.isLockStale(now);
    final isLockedByMe = item.lockedBy == currentUser?.uid;

    Color statusColor;
    IconData statusIcon;
    switch (item.status) {
      case GroceryStatus.purchased:
        statusColor = AppColors.moss;
        statusIcon = Icons.check_circle;
        break;
      case GroceryStatus.unavailable:
        statusColor = AppColors.rust;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppColors.gold;
        statusIcon = Icons.radio_button_unchecked;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        borderColor: isLockedByMe ? AppColors.forest : AppColors.line,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Status icon
            GestureDetector(
              onTap: item.status == GroceryStatus.pending
                  ? () => _showStatusDialog(context, ref)
                  : () => _resetToPending(ref),
              child: Icon(statusIcon, color: statusColor, size: 26),
            ),
            const SizedBox(width: 12),

            // Name + qty
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    style: AppTypography.bodyLarge.copyWith(
                      decoration: item.status != GroceryStatus.pending
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.status != GroceryStatus.pending
                          ? AppColors.inkMuted
                          : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text('Qty: ${item.quantity}', style: AppTypography.bodySmall),
                      if (item.purchasedQuantity > 0 &&
                          item.purchasedQuantity != item.quantity) ...[
                        Text(' · Got: ${item.purchasedQuantity}',
                            style: AppTypography.bodySmall.copyWith(
                                color: AppColors.moss)),
                      ],
                      if (isLocked && !isLockedByMe) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Being bought',
                              style: AppTypography.bodySmall
                                  .copyWith(color: AppColors.gold)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            if (isOwner && item.status == GroceryStatus.pending)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.inkMuted),
                    onPressed: () => _showEditSheet(context, ref),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rust),
                    onPressed: () => _confirmDelete(context, ref),
                    tooltip: 'Delete',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showStatusDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Update "${item.itemName}"', style: AppTypography.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: AppColors.moss),
              title: const Text('Mark as Purchased'),
              onTap: () {
                Navigator.of(ctx).pop();
                _markPurchased(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: AppColors.rust),
              title: const Text('Mark as Unavailable'),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(groceryControllerProvider.notifier).updateStatus(
                      itemId: item.id,
                      newStatus: GroceryStatus.unavailable,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _markPurchased(BuildContext context, WidgetRef ref) {
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Quantity bought?', style: AppTypography.titleLarge),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity purchased'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.forest),
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? item.quantity;
              Navigator.of(ctx).pop();
              ref.read(groceryControllerProvider.notifier).updateStatus(
                    itemId: item.id,
                    newStatus: GroceryStatus.purchased,
                    purchasedQuantity: qty,
                  );
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _resetToPending(WidgetRef ref) {
    ref.read(groceryControllerProvider.notifier).updateStatus(
          itemId: item.id,
          newStatus: GroceryStatus.pending,
          purchasedQuantity: 0,
        );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditItemSheet(item: item),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Remove "${item.itemName}"?', style: AppTypography.titleLarge),
        content: Text(
          'This will permanently remove the item from the shared list.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: AppTypography.labelLarge.copyWith(color: AppColors.inkMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rust),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(groceryControllerProvider.notifier).deleteItem(item.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Add Item Sheet ───────────────────────────────────────────────────────────

class _AddItemSheet extends ConsumerStatefulWidget {
  const _AddItemSheet();

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  List<String> _suggestions = [];
  bool _suggestionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final groupId = ref.read(activeGroupIdProvider);
    if (groupId == null) return;
    final suggestions =
        await ref.read(groceryRepositoryProvider).getSuggestions(groupId);
    if (mounted) {
      setState(() {
        _suggestions = suggestions;
        _suggestionsLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
    final ok = await ref
        .read(groceryControllerProvider.notifier)
        .addItem(itemName: _nameCtrl.text.trim(), quantity: qty);
    if (mounted) {
      setState(() => _loading = false);
      if (ok) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Add Item', style: AppTypography.titleLarge),
            const SizedBox(height: 16),

            // Item name
            AppTextField(
              controller: _nameCtrl,
              label: 'Item Name',
              hintText: 'e.g. Whole milk, Oats, Bananas',
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter an item name.';
                if (v.trim().length > 255) return 'Name too long (max 255 characters).';
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Quantity
            AppTextField(
              controller: _qtyCtrl,
              label: 'Quantity',
              hintText: '1',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 1 || n > 999) return 'Enter a quantity between 1 and 999.';
                return null;
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),

            // Suggestions
            if (_suggestionsLoaded && _suggestions.isNotEmpty) ...[
              Text('Suggestions', style: AppTypography.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _suggestions.map((s) {
                  return ActionChip(
                    label: Text(s, style: AppTypography.labelMedium),
                    backgroundColor: AppColors.sage,
                    onPressed: () => _nameCtrl.text = s,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Error from controller
            Consumer(builder: (context, ref, _) {
              final state = ref.watch(groceryControllerProvider);
              if (state is AsyncError) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    state.error.toString(),
                    style: AppTypography.bodySmall.copyWith(color: AppColors.rust),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),

            const SizedBox(height: 8),
            AppButton(
              text: 'Add to List',
              isLoading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Item Sheet ──────────────────────────────────────────────────────────

class _EditItemSheet extends ConsumerStatefulWidget {
  const _EditItemSheet({required this.item});

  final GroceryItem item;

  @override
  ConsumerState<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends ConsumerState<_EditItemSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.itemName);
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? widget.item.quantity;
    final nameChanged = _nameCtrl.text.trim() != widget.item.itemName;
    final qtyChanged = qty != widget.item.quantity;

    if (!nameChanged && !qtyChanged) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final ok = await ref.read(groceryControllerProvider.notifier).updateItem(
          itemId: widget.item.id,
          itemName: nameChanged ? _nameCtrl.text.trim() : null,
          quantity: qtyChanged ? qty : null,
        );
    if (mounted) {
      setState(() => _loading = false);
      if (ok) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Edit Item', style: AppTypography.titleLarge),
            const SizedBox(height: 16),
            AppTextField(
              controller: _nameCtrl,
              label: 'Item Name',
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter an item name.';
                if (v.trim().length > 255) return 'Name too long.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _qtyCtrl,
              label: 'Quantity',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n < 1 || n > 999) return 'Enter between 1 and 999.';
                return null;
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            AppButton(
              text: 'Save Changes',
              isLoading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
