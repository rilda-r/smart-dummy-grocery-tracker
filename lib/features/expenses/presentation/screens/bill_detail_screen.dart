import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../groups/presentation/controllers/groups_controller.dart';
import '../../data/services/expense_split_calculator.dart';
import '../../domain/models/bill.dart';
import '../controllers/expenses_controller.dart';

class BillDetailScreen extends ConsumerStatefulWidget {
  const BillDetailScreen({
    super.key,
    required this.bill,
  });

  final Bill bill;

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  late Bill _currentBill;

  @override
  void initState() {
    super.initState();
    _currentBill = widget.bill;
  }

  @override
  Widget build(BuildContext context) {
    final activeGroup = ref.watch(activeGroupProvider);
    final currentUser = ref.watch(currentUserProvider);
    final membersAsync = ref.watch(activeGroupMembersProvider);
    final itemsAsync = ref.watch(billItemsStreamProvider(_currentBill.id));

    if (activeGroup == null) {
      return const Scaffold(
        backgroundColor: AppColors.paper,
        body: Center(child: Text('No active group')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text(_currentBill.fileName.isEmpty ? 'Bill Details' : _currentBill.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Item',
            onPressed: () => _showAddItemDialog(context, activeGroup.id),
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.forest)),
        error: (e, _) => Center(child: Text('Error loading members: $e')),
        data: (members) {
          final Map<String, String> memberMap = {
            for (final m in members) m.userId: m.displayName,
          };

          return itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.forest)),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (items) {
              final computedTotal = items.fold<double>(0.0, (sum, i) => sum + i.totalPrice);
              final displayTotal = computedTotal > 0 ? computedTotal : _currentBill.totalAmount;

              return Column(
                children: [
                  // Bill Summary Banner
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
                              'Total Amount',
                              style: AppTypography.bodySmall.copyWith(color: AppColors.inkMuted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${displayTotal.toStringAsFixed(2)}',
                              style: AppTypography.headlineMedium.copyWith(color: AppColors.forest),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _currentBill.splitConfirmed
                                ? AppColors.moss.withAlpha(30)
                                : AppColors.gold.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _currentBill.splitConfirmed ? 'Split Confirmed' : 'Unsplit',
                            style: AppTypography.labelMedium.copyWith(
                              color: _currentBill.splitConfirmed ? AppColors.moss : AppColors.gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Line Items List
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.inkMuted),
                                const SizedBox(height: 12),
                                Text('No line items parsed yet.', style: AppTypography.bodyLarge),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => _showAddItemDialog(context, activeGroup.id),
                                  child: const Text('Add an item manually'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return AppCard(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.itemName, style: AppTypography.bodyLarge),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} × \$${item.unitPrice.toStringAsFixed(2)} = \$${item.totalPrice.toStringAsFixed(2)}',
                                            style: AppTypography.bodySmall,
                                          ),
                                          const SizedBox(height: 8),
                                          // Member assignment selector
                                          Row(
                                            children: [
                                              Text('Assign to: ', style: AppTypography.bodySmall),
                                              DropdownButton<String?>(
                                                value: item.assignedUserId,
                                                hint: Text('Everyone / Shared', style: AppTypography.bodySmall),
                                                isDense: true,
                                                underline: const SizedBox(),
                                                items: [
                                                  const DropdownMenuItem(
                                                    value: null,
                                                    child: Text('Unassigned'),
                                                  ),
                                                  ...members.map(
                                                    (m) => DropdownMenuItem(
                                                      value: m.userId,
                                                      child: Text(
                                                        m.displayName +
                                                            (m.userId == currentUser?.uid ? ' (You)' : ''),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                onChanged: (newUid) {
                                                  final updated = item.copyWith(
                                                    assignedUserId: newUid,
                                                    clearAssignment: newUid == null,
                                                  );
                                                  ref.read(expensesControllerProvider.notifier).updateItem(
                                                        groupId: activeGroup.id,
                                                        billId: _currentBill.id,
                                                        item: updated,
                                                      );
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.rust, size: 20),
                                      onPressed: () {
                                        ref.read(expensesControllerProvider.notifier).deleteItem(
                                              groupId: activeGroup.id,
                                              billId: _currentBill.id,
                                              itemId: item.id,
                                            );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Bottom Action: Split Bill
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: 'Equal Split',
                            variant: AppButtonVariant.secondary,
                            onPressed: () => _confirmEqualSplit(
                              context,
                              activeGroup.id,
                              displayTotal,
                              members.map((m) => m.userId).toList(),
                              memberMap,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppButton(
                            text: 'Itemized Split',
                            variant: AppButtonVariant.primary,
                            onPressed: () => _confirmMemberWiseSplit(
                              context,
                              activeGroup.id,
                              displayTotal,
                              items,
                              members.map((m) => m.userId).toList(),
                              memberMap,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showAddItemDialog(BuildContext context, String groupId) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Add Line Item', style: AppTypography.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Total price (\$)'),
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
              final name = nameCtrl.text.trim();
              final qty = double.tryParse(qtyCtrl.text.trim()) ?? 1.0;
              final total = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
              if (name.isEmpty || total <= 0) return;

              final unit = qty > 0 ? total / qty : total;
              Navigator.of(ctx).pop();

              await ref.read(expensesControllerProvider.notifier).addItem(
                    groupId: groupId,
                    billId: _currentBill.id,
                    itemName: name,
                    quantity: qty,
                    unitPrice: (unit * 100).round() / 100,
                    totalPrice: (total * 100).round() / 100,
                  );
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmEqualSplit(
    BuildContext context,
    String groupId,
    double total,
    List<String> memberIds,
    Map<String, String> memberNames,
  ) {
    final result = ExpenseSplitCalculator.calculateEqualSplit(
      billId: _currentBill.id,
      totalAmount: total,
      paidBy: _currentBill.uploadedBy,
      memberIds: memberIds,
    );

    _showSplitPreviewModal(
      context,
      groupId: groupId,
      splitType: 'equal',
      result: result,
      memberNames: memberNames,
    );
  }

  void _confirmMemberWiseSplit(
    BuildContext context,
    String groupId,
    double total,
    List<BillItem> items,
    List<String> memberIds,
    Map<String, String> memberNames,
  ) {
    // Check if any items are unassigned
    final unassigned = items.where((i) => i.assignedUserId == null).toList();
    if (unassigned.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${unassigned.length} items are unassigned. Assign all items to members before itemized split, or use Equal Split.',
          ),
          backgroundColor: AppColors.rust,
        ),
      );
      return;
    }

    final subtotals = <String, double>{};
    for (final item in items) {
      final uid = item.assignedUserId!;
      subtotals[uid] = (subtotals[uid] ?? 0.0) + item.totalPrice;
    }

    final result = ExpenseSplitCalculator.calculateMemberWiseSplit(
      billId: _currentBill.id,
      totalAmount: total,
      paidBy: _currentBill.uploadedBy,
      memberSubtotals: subtotals,
    );

    _showSplitPreviewModal(
      context,
      groupId: groupId,
      splitType: 'member_wise',
      result: result,
      memberNames: memberNames,
    );
  }

  void _showSplitPreviewModal(
    BuildContext context,
    {
    required String groupId,
    required String splitType,
    required BillSplitResult result,
    required Map<String, String> memberNames,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm ${splitType == 'equal' ? 'Equal' : 'Itemized'} Split',
                style: AppTypography.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Each member will owe their share to ${_currentBill.uploadedBy == ref.read(currentUserProvider)?.uid ? 'you' : (memberNames[_currentBill.uploadedBy] ?? 'the payer')}.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 16),
            ...result.shares.map((share) {
              final isPayer = share.userId == _currentBill.uploadedBy;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      memberNames[share.userId] ?? share.userId,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: isPayer ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      isPayer
                          ? '\$${share.amount.toStringAsFixed(2)} (Paid bill)'
                          : '\$${share.amount.toStringAsFixed(2)}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: isPayer ? AppColors.forest : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            AppButton(
              text: 'Confirm and Generate Payments',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.of(ctx).pop();
                final ok = await ref.read(expensesControllerProvider.notifier).confirmSplit(
                      groupId: groupId,
                      bill: _currentBill,
                      shares: result.shares,
                      splitType: splitType,
                      memberNames: memberNames,
                    );
                if (ok && mounted) {
                  setState(() {
                    _currentBill = _currentBill.copyWith(
                      splitConfirmed: true,
                      splitType: splitType,
                    );
                  });
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Split confirmed and payment obligations generated!'),
                      backgroundColor: AppColors.forest,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
