import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/auth_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // 1. Cart slides in from left with overshoot bounce
  late final Animation<Offset> _cartSlideAnimation;

  // 2. Apple drops into the cart with a bounce
  late final Animation<Offset> _appleDropAnimation;
  late final Animation<double> _appleOpacityAnimation;

  // 3. GrocEase brand scales in with bounce
  late final Animation<double> _titleScaleAnimation;
  late final Animation<double> _titleOpacityAnimation;

  // 4. Tagline fades up
  late final Animation<Offset> _taglineSlideAnimation;
  late final Animation<double> _taglineOpacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Cart animation: 0.0 -> 0.35
    _cartSlideAnimation = Tween<Offset>(
      begin: const Offset(-2.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    // Apple animation: 0.35 -> 0.65
    _appleDropAnimation = Tween<Offset>(
      begin: const Offset(0.0, -2.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.65, curve: Curves.bounceOut),
      ),
    );
    _appleOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.45, curve: Curves.easeIn),
      ),
    );

    // Brand Title: 0.60 -> 0.85
    _titleScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.85, curve: Curves.elasticOut),
      ),
    );
    _titleOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.60, 0.70, curve: Curves.easeIn),
      ),
    );

    // Tagline: 0.80 -> 1.0
    _taglineSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.80, 1.0, curve: Curves.easeOut),
      ),
    );
    _taglineOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.80, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateNext();
      }
    });
  }

  void _navigateNext() {
    if (!mounted) return;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/login');
    } else if (!user.emailVerified) {
      context.go('/verify-email');
    } else {
      context.go('/home');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.forest,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Stack (Cart + Apple)
                  SizedBox(
                    height: 120,
                    width: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // 1. Sliding Cart 🛒
                        SlideTransition(
                          position: _cartSlideAnimation,
                          child: const Text(
                            '🛒',
                            style: TextStyle(fontSize: 64),
                          ),
                        ),
                        // 2. Dropping Apple 🍏
                        Positioned(
                          top: 10,
                          child: SlideTransition(
                            position: _appleDropAnimation,
                            child: FadeTransition(
                              opacity: _appleOpacityAnimation,
                              child: const Text(
                                '🍏',
                                style: TextStyle(fontSize: 32),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 3. GrocEase Title
                  FadeTransition(
                    opacity: _titleOpacityAnimation,
                    child: ScaleTransition(
                      scale: _titleScaleAnimation,
                      child: Text(
                        AppConstants.appName,
                        style: GoogleFonts.fraunces(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: AppColors.paper,
                          letterSpacing: -1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 4. Tagline
                  FadeTransition(
                    opacity: _taglineOpacityAnimation,
                    child: SlideTransition(
                      position: _taglineSlideAnimation,
                      child: Text(
                        AppConstants.appTagline,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppColors.sage,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
