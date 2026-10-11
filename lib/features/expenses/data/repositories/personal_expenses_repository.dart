import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/budget.dart';
import '../../domain/models/personal_expense.dart';

final personalExpensesRepositoryProvider =
    Provider<PersonalExpensesRepository>((ref) {
  return PersonalExpensesRepository(FirebaseFirestore.instance);
});

class PersonalExpensesRepository {
  PersonalExpensesRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _expensesCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('personalExpenses');

  CollectionReference<Map<String, dynamic>> _budgetsCol(String userId) =>
      _firestore.collection('users').doc(userId).collection('budgets');

  // ─── Personal Expenses ──────────────────────────────────────────────────────

  Stream<List<PersonalExpense>> watchPersonalExpenses(String userId) {
    return _expensesCol(userId)
        .orderBy('expenseDate', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(PersonalExpense.fromFirestore).toList());
  }

  Future<PersonalExpense> addExpense({
    required String userId,
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? description,
  }) async {
    final doc = _expensesCol(userId).doc();
    final expense = PersonalExpense(
      id: doc.id,
      userId: userId,
      amount: amount,
      category: category,
      expenseDate: expenseDate,
      description: description,
      createdAt: DateTime.now(),
    );
    await doc.set(expense.toFirestore());
    return expense;
  }

  Future<void> updateExpense({
    required String userId,
    required PersonalExpense expense,
  }) async {
    await _expensesCol(userId).doc(expense.id).update(expense.toFirestore());
  }

  Future<void> deleteExpense({
    required String userId,
    required String expenseId,
  }) async {
    await _expensesCol(userId).doc(expenseId).delete();
  }

  // ─── Budgets ────────────────────────────────────────────────────────────────

  Stream<List<Budget>> watchBudgets(String userId) {
    return _budgetsCol(userId).snapshots().map((snap) =>
        snap.docs.map(Budget.fromFirestore).toList());
  }

  Future<void> setBudget({
    required String userId,
    required String category,
    required double monthlyLimit,
  }) async {
    // Check if category already has a budget document
    final existing = await _budgetsCol(userId)
        .where('category', isEqualTo: category)
        .limit(1)
        .get();

    final now = DateTime.now();
    if (existing.docs.isNotEmpty) {
      await existing.docs.first.reference.update({
        'monthlyLimit': monthlyLimit,
        'updatedAt': Timestamp.fromDate(now),
      });
    } else {
      final doc = _budgetsCol(userId).doc();
      final budget = Budget(
        id: doc.id,
        userId: userId,
        category: category,
        monthlyLimit: monthlyLimit,
        updatedAt: now,
      );
      await doc.set(budget.toFirestore());
    }
  }

  Future<void> deleteBudget({
    required String userId,
    required String budgetId,
  }) async {
    await _budgetsCol(userId).doc(budgetId).delete();
  }
}
