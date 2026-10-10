import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_empty_state.dart';

class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Shared Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: const SafeArea(
        child: AppEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No grocery lists yet',
          description: 'Create a list or select a group to start shopping together.',
          actionLabel: 'Create New List',
        ),
      ),
    );
  }
}
