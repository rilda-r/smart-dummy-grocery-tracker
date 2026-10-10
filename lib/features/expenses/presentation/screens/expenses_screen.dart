import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Spend & Balances'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: const SafeArea(
        child: AppEmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'No expenses recorded',
          description: 'Scan receipts with OCR or record expenses manually to split costs.',
          actionLabel: 'Scan Receipt',
        ),
      ),
    );
  }
}
