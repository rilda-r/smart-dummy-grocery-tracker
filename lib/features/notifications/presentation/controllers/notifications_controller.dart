import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/data/auth_repository.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../domain/models/app_notification.dart';

final notificationsStreamProvider =
    StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.watchNotifications(user.uid);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifsAsync = ref.watch(notificationsStreamProvider);
  return notifsAsync.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

final notificationsControllerProvider =
    Provider<NotificationsController>((ref) {
  return NotificationsController(ref);
});

class NotificationsController {
  NotificationsController(this._ref);

  final Ref _ref;

  NotificationsRepository get _repo =>
      _ref.read(notificationsRepositoryProvider);

  String? get _currentUserId => _ref.read(currentUserProvider)?.uid;

  Future<void> markAsRead(String notifId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _repo.markAsRead(uid, notifId);
  }

  Future<void> markAllAsRead() async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _repo.markAllAsRead(uid);
  }

  Future<void> deleteNotification(String notifId) async {
    final uid = _currentUserId;
    if (uid == null) return;
    await _repo.deleteNotification(uid, notifId);
  }
}
