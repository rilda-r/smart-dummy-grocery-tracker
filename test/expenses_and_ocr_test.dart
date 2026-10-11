import 'package:flutter_test/flutter_test.dart';
import 'package:grocease/features/expenses/data/services/bill_ocr_parser.dart';
import 'package:grocease/features/expenses/data/services/expense_split_calculator.dart';
import 'package:grocease/features/expenses/domain/models/budget.dart';
import 'package:grocease/features/lists/domain/models/grocery_item.dart';

void main() {
  group('Bill OCR Parser Tests', () {
    test('parses simple line items with item name and total price', () {
      const rawText = '''
        SUPERMARKET RECEIPT
        Organic Whole Milk 3.99
        Sourdough Bread 4.50
        2 Honey Crisp Apples 5.00
        SUBTOTAL 13.49
        TAX 1.08
        GRAND TOTAL 14.57
        CASH 20.00
      ''';

      final items = BillOcrParser.parseText(rawText);
      expect(items.length, 3);

      expect(items[0].itemName, 'Organic Whole Milk');
      expect(items[0].totalPrice, 3.99);
      expect(items[0].quantity, 1.0);

      expect(items[1].itemName, 'Sourdough Bread');
      expect(items[1].totalPrice, 4.50);

      expect(items[2].itemName, 'Honey Crisp Apples');
      expect(items[2].quantity, 2.0);
      expect(items[2].totalPrice, 5.00);
    });

    test('ignores noise headers and footers', () {
      const noise = '''
        STORE #1234
        TAX INVOICE
        DATE: 2026-10-11
        SUB-TOTAL 45.00
        GST 4.50
        TOTAL AMOUNT 49.50
        CARD TENDERED 49.50
        THANK YOU FOR SHOPPING!
      ''';

      final items = BillOcrParser.parseText(noise);
      expect(items, isEmpty);
    });

    test('parses currency prefixes correctly', () {
      const text = 'Organic Bananas \$2.50';
      final items = BillOcrParser.parseText(text);
      expect(items.length, 1);
      expect(items.first.itemName, 'Organic Bananas');
      expect(items.first.totalPrice, 2.50);
    });
  });

  group('Expense Split & Financial Calculator Tests', () {
    test('equal split of 10.00 among 3 members reconciles exact cents (largest remainder)', () {
      final result = ExpenseSplitCalculator.calculateEqualSplit(
        billId: 'bill_1',
        totalAmount: 10.00,
        paidBy: 'user_1',
        memberIds: ['user_1', 'user_2', 'user_3'],
      );

      expect(result.shares.length, 3);
      final sum = result.shares.fold<double>(0.0, (s, share) => s + share.amount);
      expect((sum * 100).round(), 1000); // exactly 10.00 dollars (1000 cents)

      // In largest remainder: 10.00 / 3 gives 3.33 + remainder 1 cent
      final amounts = result.shares.map((s) => s.amount).toList()..sort();
      expect(amounts, [3.33, 3.33, 3.34]);
    });

    test('member-wise split allocates bill total proportionally to item subtotals', () {
      final subtotals = {
        'alice': 20.00,
        'bob': 30.00,
      };

      // Bill total including tax/tip is 55.00
      final result = ExpenseSplitCalculator.calculateMemberWiseSplit(
        billId: 'bill_2',
        totalAmount: 55.00,
        paidBy: 'alice',
        memberSubtotals: subtotals,
      );

      expect(result.shares.length, 2);
      final sum = result.shares.fold<double>(0.0, (s, share) => s + share.amount);
      expect((sum * 100).round(), 5500); // exactly 55.00 dollars

      final aliceShare = result.shares.firstWhere((s) => s.userId == 'alice').amount;
      final bobShare = result.shares.firstWhere((s) => s.userId == 'bob').amount;

      expect(aliceShare, 22.00); // 20/50 * 55 = 22.00
      expect(bobShare, 33.00); // 30/50 * 55 = 33.00
    });
  });

  group('GroceryItem Model & Purchase Locking Tests', () {
    test('lock expiry detection after 10 minutes', () {
      final now = DateTime.now();
      final freshItem = GroceryItem(
        id: 'item_1',
        groupId: 'grp_1',
        addedBy: 'user_1',
        itemName: 'Eggs',
        itemNameLower: 'eggs',
        quantity: 12,
        status: GroceryStatus.pending,
        lockedBy: 'user_2',
        lockedAt: now.subtract(const Duration(minutes: 5)),
        createdAt: now,
        updatedAt: now,
      );

      expect(freshItem.isLocked, isTrue);
      expect(freshItem.isLockStale(now), isFalse);

      final staleItem = freshItem.copyWith(
        lockedAt: now.subtract(const Duration(minutes: 15)),
      );
      expect(staleItem.isLockStale(now), isTrue);
    });
  });

  group('Budget Usage Computation Tests', () {
    test('computes remaining balance and percentage correctly', () {
      final underBudget = BudgetUsage.compute(
        category: 'Groceries',
        limit: 200.0,
        spent: 150.0,
      );
      expect(underBudget.remaining, 50.0);
      expect(underBudget.percentageUsed, 75.0);
      expect(underBudget.exceeded, isFalse);

      final overBudget = BudgetUsage.compute(
        category: 'Dining',
        limit: 100.0,
        spent: 120.0,
      );
      expect(overBudget.remaining, 0.0);
      expect(overBudget.percentageUsed, 120.0);
      expect(overBudget.exceeded, isTrue);
    });
  });
}
