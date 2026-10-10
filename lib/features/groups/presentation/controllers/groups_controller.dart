import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/repositories/groups_repository.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';

/// Stream of all groups the current user belongs to
final userGroupsProvider = StreamProvider<List<Group>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.watchUserGroups(user.uid);
});

/// Currently active group ID in the app
final activeGroupIdProvider = StateProvider<String?>((ref) {
  // If not explicitly selected, default to first available group
  final groupsAsync = ref.watch(userGroupsProvider);
  return groupsAsync.when(
    data: (groups) => groups.isNotEmpty ? groups.first.id : null,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Currently active group object
final activeGroupProvider = Provider<Group?>((ref) {
  final activeId = ref.watch(activeGroupIdProvider);
  final groupsAsync = ref.watch(userGroupsProvider);
  return groupsAsync.when(
    data: (groups) {
      if (groups.isEmpty) return null;
      if (activeId == null) return groups.first;
      return groups.firstWhere(
        (g) => g.id == activeId,
        orElse: () => groups.first,
      );
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Stream of members for a specific group
final groupMembersProvider = StreamProvider.family<List<GroupMember>, String>((ref, groupId) {
  if (groupId.isEmpty) return Stream.value([]);
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.watchGroupMembers(groupId);
});

/// Controller handling user actions (create, join, leave group)
final groupsControllerProvider =
    StateNotifierProvider<GroupsController, AsyncValue<void>>((ref) {
  return GroupsController(ref);
});

class GroupsController extends StateNotifier<AsyncValue<void>> {
  GroupsController(this._ref) : super(const AsyncValue.data(null));

  final Ref _ref;

  Future<Group?> createGroup({
    required String name,
    required String currency,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncValue.error('User not authenticated.', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groupsRepositoryProvider);
      final group = await repo.createGroup(
        name: name,
        currency: currency,
        user: user,
      );
      // Automatically switch to the newly created group
      _ref.read(activeGroupIdProvider.notifier).state = group.id;
      state = const AsyncValue.data(null);
      return group;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<Group?> joinGroupWithCode(String code) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncValue.error('User not authenticated.', StackTrace.current);
      return null;
    }

    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groupsRepositoryProvider);
      final group = await repo.joinGroupWithCode(
        code: code,
        user: user,
      );
      // Automatically switch to joined group
      _ref.read(activeGroupIdProvider.notifier).state = group.id;
      state = const AsyncValue.data(null);
      return group;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<String?> regenerateJoinCode(String groupId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return null;

    try {
      final repo = _ref.read(groupsRepositoryProvider);
      return await repo.regenerateJoinCode(
        groupId: groupId,
        requesterId: user.uid,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> leaveGroup(String groupId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(groupsRepositoryProvider);
      await repo.leaveGroup(
        groupId: groupId,
        userId: user.uid,
      );
      if (_ref.read(activeGroupIdProvider) == groupId) {
        _ref.read(activeGroupIdProvider.notifier).state = null;
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
