import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/repositories/personal_expenses_repository.dart';
import '../../domain/models/budget.dart';
import '../../domain/models/personal_expense.dart';

final personalExpensesStreamProvider =
    StreamProvider<List<PersonalExpense>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref
      .watch(personalExpensesRepositoryProvider)
      .watchPersonalExpenses(user.uid);
});

final budgetsStreamProvider = StreamProvider<List<Budget>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(personalExpensesRepositoryProvider).watchBudgets(user.uid);
});

final personalExpensesControllerProvider =
    StateNotifierProvider<PersonalExpensesController, AsyncValue<void>>((ref) {
  return PersonalExpensesController(ref);
});

class PersonalExpensesController extends StateNotifier<AsyncValue<void>> {
  PersonalExpensesController(this._ref) : super(const AsyncData(null));

  final Ref _ref;
  PersonalExpensesRepository get _repo =>
      _ref.read(personalExpensesRepositoryProvider);

  Future<void> addExpense({
    required double amount,
    required String category,
    required DateTime expenseDate,
    String? description,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await _repo.addExpense(
        userId: user.uid,
        amount: amount,
        category: category,
        expenseDate: expenseDate,
        description: description,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> updateExpense(PersonalExpense expense) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await _repo.updateExpense(userId: user.uid, expense: expense);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await _repo.deleteExpense(userId: user.uid, expenseId: expenseId);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> setBudget({
    required String category,
    required double monthlyLimit,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await _repo.setBudget(
        userId: user.uid,
        category: category,
        monthlyLimit: monthlyLimit,
      );
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    try {
      await _repo.deleteBudget(userId: user.uid, budgetId: budgetId);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
