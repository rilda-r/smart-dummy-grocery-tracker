import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/auth_repository.dart';

/// Configurable inactivity timeout (default 15 minutes)
const Duration kInactivityTimeout = Duration(minutes: 15);

class InactivityListener extends ConsumerStatefulWidget {
  const InactivityListener({
    super.key,
    required this.child,
    this.timeout = kInactivityTimeout,
  });

  final Widget child;
  final Duration timeout;

  @override
  ConsumerState<InactivityListener> createState() => _InactivityListenerState();
}

class _InactivityListenerState extends ConsumerState<InactivityListener> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _resetTimer() {
    _timer?.cancel();
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    _timer = Timer(widget.timeout, _handleTimeout);
  }

  Future<void> _handleTimeout() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null && mounted) {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) {
        context.go('/login?reason=${Uri.encodeComponent('You were logged out due to inactivity.')}');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resetTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
