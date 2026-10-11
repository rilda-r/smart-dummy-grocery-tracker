import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/repositories/groups_repository.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// Stream of all groups the current user belongs to
final userGroupsProvider = StreamProvider<List<Group>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  final repo = ref.watch(groupsRepositoryProvider);
  return repo.watchUserGroups(user.uid);
});

/// Active group ID notifier with SharedPreferences persistence across app restarts
class ActiveGroupIdNotifier extends StateNotifier<String?> {
  ActiveGroupIdNotifier(this._ref) : super(null) {
    _init();
  }

  final Ref _ref;
  static const _prefKey = 'active_group_id';

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_prefKey);
      if (savedId != null && state == null) {
        state = savedId;
      }
    } catch (_) {}

    _ref.listen<AsyncValue<List<Group>>>(userGroupsProvider, (previous, next) {
      next.whenData((groups) {
        if (groups.isEmpty) {
          state = null;
        } else {
          final exists = groups.any((g) => g.id == state);
          if (!exists) {
            SharedPreferences.getInstance().then((prefs) {
              final savedId = prefs.getString(_prefKey);
              if (savedId != null && groups.any((g) => g.id == savedId)) {
                state = savedId;
              } else {
                state = groups.first.id;
                prefs.setString(_prefKey, groups.first.id);
              }
            }).catchError((_) {
              state = groups.first.id;
            });
          }
        }
      });
    }, fireImmediately: true);
  }

  Future<void> setActiveGroup(String? groupId) async {
    state = groupId;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (groupId != null) {
        await prefs.setString(_prefKey, groupId);
      } else {
        await prefs.remove(_prefKey);
      }
    } catch (_) {}
  }
}

final activeGroupIdProvider =
    StateNotifierProvider<ActiveGroupIdNotifier, String?>((ref) {
  return ActiveGroupIdNotifier(ref);
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

/// Members of currently active group
final activeGroupMembersProvider = Provider<AsyncValue<List<GroupMember>>>((ref) {
  final activeId = ref.watch(activeGroupIdProvider);
  if (activeId == null) return const AsyncValue.data([]);
  return ref.watch(groupMembersProvider(activeId));
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
      await _ref.read(activeGroupIdProvider.notifier).setActiveGroup(group.id);
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
      await _ref.read(activeGroupIdProvider.notifier).setActiveGroup(group.id);
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
        await _ref.read(activeGroupIdProvider.notifier).setActiveGroup(null);
      }
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
