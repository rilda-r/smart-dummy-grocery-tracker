import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../groups/presentation/controllers/groups_controller.dart';
import '../../domain/models/bill.dart';
import '../../domain/models/payment.dart';
import '../controllers/expenses_controller.dart';
import 'bill_detail_screen.dart';
import '../../../groups/presentation/widgets/room_switcher_title.dart';
import '../../../notifications/presentation/widgets/notification_bell_icon.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
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
    final activeGroup = ref.watch(activeGroupProvider);
    final currentUser = ref.watch(currentUserProvider);

    if (activeGroup == null) {
      return Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(title: const Text('Spend & Balances')),
        body: AppEmptyState(
          icon: Icons.group_off_outlined,
          title: 'No group selected',
          description: 'Join or create a group to view and split shared expenses.',
          actionLabel: 'Go to Groups',
          onActionPressed: () => context.go('/groups'),
        ),
      );
    }

    final billsAsync = ref.watch(billsStreamProvider);
    final paymentsAsync = ref.watch(paymentsStreamProvider);
    final membersAsync = ref.watch(activeGroupMembersProvider);

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const RoomSwitcherAppBarTitle(fallbackTitle: 'Spend & Balances'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan Receipt',
            onPressed: () => _pickAndScanReceipt(context, ImageSource.camera),
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Upload Receipt from Gallery',
            onPressed: () => _pickAndScanReceipt(context, ImageSource.gallery),
          ),
          const NotificationBellIcon(),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.forest,
          unselectedLabelColor: AppColors.inkMuted,
          indicatorColor: AppColors.forest,
          tabs: const [
            Tab(text: 'Balances'),
            Tab(text: 'Group Bills'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Balances & Debts
          paymentsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (payments) {
              return membersAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.forest),
                ),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (members) {
                  return _BalancesTab(
                    groupId: activeGroup.id,
                    currentUserId: currentUser?.uid ?? '',
                    payments: payments,
                    members: members,
                  );
                },
              );
            },
          ),

          // Tab 2: Group Bills
          billsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (bills) {
              return _BillsTab(
                bills: bills,
                onScan: () => _pickAndScanReceipt(context, ImageSource.gallery),
                onManual: () => _showManualBillDialog(context, activeGroup.id),
              );
            },
          ),

          // Tab 3: History of Settled Payments
          paymentsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (payments) {
              final settled = payments.where((p) => !p.isPending).toList();
              if (settled.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.history_outlined,
                  title: 'No settled payments yet',
                  description: 'Past settled payments will be archived here.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: settled.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final p = settled[index];
                  return AppCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.sage,
                        child: Icon(Icons.check, color: AppColors.forest),
                      ),
                      title: Text(
                        '${p.payerName ?? 'Member'} paid ${p.payeeName ?? 'Member'}',
                        style: AppTypography.bodyMedium,
                      ),
                      subtitle: Text(
                        p.settledAt != null
                            ? 'Settled on ${p.settledAt!.toLocal().toString().split(' ')[0]}'
                            : 'Settled',
                        style: AppTypography.bodySmall,
                      ),
                      trailing: Text(
                        '\$${p.amount.toStringAsFixed(2)}',
                        style: AppTypography.titleLarge.copyWith(color: AppColors.forest),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.forest,
        icon: const Icon(Icons.receipt_long, color: Colors.white),
        label: const Text('Add Bill', style: TextStyle(color: Colors.white)),
        onPressed: () => _showAddBillOptions(context, activeGroup.id),
      ),
    );
  }

  void _showAddBillOptions(BuildContext context, String groupId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.forest),
                title: const Text('Take Photo of Receipt'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndScanReceipt(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.forest),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAndScanReceipt(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_outlined, color: AppColors.forest),
                title: const Text('Enter Bill Manually'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showManualBillDialog(context, groupId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndScanReceipt(BuildContext context, ImageSource source) async {
    final activeGroup = ref.read(activeGroupProvider);
    final currentUser = ref.read(currentUserProvider);
    if (activeGroup == null || currentUser == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source);
      if (file == null) return;

      messenger.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              SizedBox(width: 16),
              Text('Analyzing receipt with OCR...'),
            ],
          ),
          duration: Duration(seconds: 4),
        ),
      );

      final bill = await ref.read(expensesControllerProvider.notifier).processBillImage(
            file: file,
            groupId: activeGroup.id,
            uploadedBy: currentUser.uid,
          );

      if (bill != null && mounted) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) => BillDetailScreen(bill: bill),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to process image: $e'),
            backgroundColor: AppColors.rust,
          ),
        );
      }
    }
  }

  void _showManualBillDialog(BuildContext context, String groupId) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final currentUser = ref.read(currentUserProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text('Record Shared Bill', style: AppTypography.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Bill Title (e.g. Grocery Trip, Utilities)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Total Amount (\$)'),
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
              final title = titleCtrl.text.trim();
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (title.isEmpty || amount <= 0 || currentUser == null) return;

              final navigator = Navigator.of(context);
              Navigator.of(ctx).pop();
              final bill = await ref.read(expensesControllerProvider.notifier).createManualBill(
                    groupId: groupId,
                    uploadedBy: currentUser.uid,
                    title: title,
                    totalAmount: amount,
                    items: [
                      BillItem(
                        id: '',
                        billId: '',
                        itemName: title,
                        quantity: 1,
                        unitPrice: amount,
                        totalPrice: amount,
                      ),
                    ],
                  );

              if (bill != null && mounted) {
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => BillDetailScreen(bill: bill),
                  ),
                );
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Balances Tab ─────────────────────────────────────────────────────────────

class _BalancesTab extends ConsumerWidget {
  const _BalancesTab({
    required this.groupId,
    required this.currentUserId,
    required this.payments,
    required this.members,
  });

  final String groupId;
  final String currentUserId;
  final List<Payment> payments;
  final List<dynamic> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = payments.where((p) => p.isPending).toList();

    // Calculate user's net totals
    double userOwed = 0.0; // People owe user
    double userOwes = 0.0; // User owes others

    for (final p in pending) {
      if (p.payeeUserId == currentUserId) {
        userOwed += p.amount;
      }
      if (p.payerUserId == currentUserId) {
        userOwes += p.amount;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Cards
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You are owed', style: AppTypography.bodySmall.copyWith(color: AppColors.forest)),
                    const SizedBox(height: 4),
                    Text(
                      '\$${userOwed.toStringAsFixed(2)}',
                      style: AppTypography.headlineMedium.copyWith(color: AppColors.forest),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.rust.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You owe', style: AppTypography.bodySmall.copyWith(color: AppColors.rust)),
                    const SizedBox(height: 4),
                    Text(
                      '\$${userOwes.toStringAsFixed(2)}',
                      style: AppTypography.headlineMedium.copyWith(color: AppColors.rust),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),
        Text('Pending Settlements', style: AppTypography.titleLarge),
        const SizedBox(height: 12),

        if (pending.isEmpty)
          const AppCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('All balances are settled! No open debts.'),
            ),
          )
        else
          ...pending.map((p) {
            final isOwedToMe = p.payeeUserId == currentUserId;
            final isMyDebt = p.payerUserId == currentUserId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isMyDebt
                                ? 'You owe ${p.payeeName ?? 'Member'}'
                                : '${p.payerName ?? 'Member'} owes ${isOwedToMe ? 'you' : (p.payeeName ?? 'Member')}',
                            style: AppTypography.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${p.amount.toStringAsFixed(2)}',
                            style: AppTypography.titleLarge.copyWith(
                              color: isMyDebt ? AppColors.rust : AppColors.forest,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOwedToMe)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.forest),
                        onPressed: () async {
                          await ref.read(expensesControllerProvider.notifier).settlePayment(
                                groupId: groupId,
                                paymentId: p.id,
                              );
                        },
                        child: const Text('Mark Settled', style: TextStyle(color: Colors.white)),
                      )
                    else if (isMyDebt)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.rust.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Payment due',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.rust),
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

// ─── Group Bills Tab ──────────────────────────────────────────────────────────

class _BillsTab extends StatelessWidget {
  const _BillsTab({
    required this.bills,
    required this.onScan,
    required this.onManual,
  });

  final List<Bill> bills;
  final VoidCallback onScan;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return AppEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No bills recorded',
        description: 'Scan receipts with OCR or record expenses manually to split costs.',
        actionLabel: 'Scan Receipt',
        onActionPressed: onScan,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: bills.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final bill = bills[index];
        return AppCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: bill.splitConfirmed ? AppColors.sage : AppColors.gold.withAlpha(40),
              child: Icon(
                bill.splitConfirmed ? Icons.check_circle_outline : Icons.pending_actions_outlined,
                color: bill.splitConfirmed ? AppColors.forest : AppColors.gold,
              ),
            ),
            title: Text(bill.fileName, style: AppTypography.bodyLarge),
            subtitle: Text(
              '${bill.createdAt.toLocal().toString().split(' ')[0]} • ${bill.splitConfirmed ? 'Split Confirmed' : 'Needs Split'}',
              style: AppTypography.bodySmall,
            ),
            trailing: Text(
              '\$${bill.totalAmount.toStringAsFixed(2)}',
              style: AppTypography.titleLarge.copyWith(color: AppColors.forest),
            ),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BillDetailScreen(bill: bill),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
