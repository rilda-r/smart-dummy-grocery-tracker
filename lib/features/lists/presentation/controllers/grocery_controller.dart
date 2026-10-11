import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../groups/presentation/controllers/groups_controller.dart';
import '../../data/repositories/grocery_repository.dart';
import '../../domain/models/grocery_item.dart';

/// Stream of grocery items for the currently active group
final groceryItemsProvider = StreamProvider<List<GroceryItem>>((ref) {
  final activeGroupId = ref.watch(activeGroupIdProvider);
  if (activeGroupId == null || activeGroupId.isEmpty) return Stream.value([]);
  final repo = ref.watch(groceryRepositoryProvider);
  return repo.watchItems(activeGroupId);
});

/// Controller for mutating grocery list items
final groceryControllerProvider =
    StateNotifierProvider<GroceryController, AsyncValue<void>>((ref) {
  return GroceryController(ref);
});

class GroceryController extends StateNotifier<AsyncValue<void>> {
  GroceryController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<bool> addItem({
    required String itemName,
    required int quantity,
    String? targetGroupId,
  }) async {
    final user = _ref.read(currentUserProvider);
    final groupId = targetGroupId ?? _ref.read(activeGroupIdProvider);
    if (user == null || groupId == null) {
      state = AsyncValue.error('Not authenticated or no group selected.', StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groceryRepositoryProvider);
      await repo.addItem(
        groupId: groupId,
        user: user,
        itemName: itemName,
        quantity: quantity,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateItem({
    required String itemId,
    String? itemName,
    int? quantity,
  }) async {
    final user = _ref.read(currentUserProvider);
    final groupId = _ref.read(activeGroupIdProvider);
    if (user == null || groupId == null) return false;

    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groceryRepositoryProvider);
      await repo.updateItem(
        groupId: groupId,
        itemId: itemId,
        requesterId: user.uid,
        itemName: itemName,
        quantity: quantity,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> deleteItem(String itemId) async {
    final user = _ref.read(currentUserProvider);
    final groupId = _ref.read(activeGroupIdProvider);
    if (user == null || groupId == null) return false;

    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groceryRepositoryProvider);
      await repo.deleteItem(
        groupId: groupId,
        itemId: itemId,
        requesterId: user.uid,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateStatus({
    required String itemId,
    required GroceryStatus newStatus,
    int? purchasedQuantity,
  }) async {
    final groupId = _ref.read(activeGroupIdProvider);
    if (groupId == null) return false;

    try {
      final repo = _ref.read(groceryRepositoryProvider);
      await repo.updateStatus(
        groupId: groupId,
        itemId: itemId,
        newStatus: newStatus,
        purchasedQuantity: purchasedQuantity,
      );
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> lockItem(String itemId) async {
    final user = _ref.read(currentUserProvider);
    final groupId = _ref.read(activeGroupIdProvider);
    if (user == null || groupId == null) return false;

    try {
      final repo = _ref.read(groceryRepositoryProvider);
      await repo.lockItem(groupId: groupId, itemId: itemId, userId: user.uid);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<void> releaseItemLock(String itemId) async {
    final user = _ref.read(currentUserProvider);
    final groupId = _ref.read(activeGroupIdProvider);
    if (user == null || groupId == null) return;

    try {
      final repo = _ref.read(groceryRepositoryProvider);
      await repo.releaseItemLock(
        groupId: groupId,
        itemId: itemId,
        userId: user.uid,
      );
    } catch (_) {}
  }
}
