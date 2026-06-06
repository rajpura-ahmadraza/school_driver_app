import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/tracking/tracking_screen.dart';
import '../../features/students/students_screen.dart';
import '../controllers/auth_controller.dart';
import '../controllers/locale_controller.dart';
import '../splash/splash_screen.dart';

// Route names
class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const home = '/home';
  static const tracking = '/tracking';
  static const students = '/students';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildAppRouter() {
  final authController = Get.find<AuthController>();
  final localeController = Get.find<LocaleController>();

  // Listenable that notifies go_router whenever auth or locale changes
  final refreshListenable = _GetxRefreshListenable([
    authController.token,
    authController.isInitializing,
    localeController.currentLocale,
  ]);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final isInitializing = authController.isInitializing.value;
      final isLoggedIn = authController.isAuthenticated;
      final isSplash = state.matchedLocation == AppRoutes.splash;
      final isLogin = state.matchedLocation == AppRoutes.login;
      final isForgotPassword =
          state.matchedLocation == AppRoutes.forgotPassword;

      // Stay on splash while initializing
      if (isInitializing) return AppRoutes.splash;

      // After init, redirect from splash appropriately
      if (isSplash) {
        return isLoggedIn ? AppRoutes.home : AppRoutes.login;
      }

      // Not logged in → login (unless heading to forgot password page)
      if (!isLoggedIn && !isLogin && !isForgotPassword) return AppRoutes.login;

      // Already logged in → don't show login or forgot password
      if (isLoggedIn && (isLogin || isForgotPassword)) return AppRoutes.home;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.tracking,
        builder: (_, __) => const TrackingScreen(),
      ),
      GoRoute(
        path: AppRoutes.students,
        pageBuilder: (context, state) {
          final routeId = int.tryParse(
                state.uri.queryParameters['route_id'] ?? '2',
              ) ??
              2;
          return CustomTransitionPage(
            key: state.pageKey,
            child: StudentsScreen(routeId: routeId),
            transitionDuration: const Duration(milliseconds: 380),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              if (animation.status == AnimationStatus.reverse) {
                final slideOut = Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeInCubic));
                return SlideTransition(
                  position: animation.drive(slideOut),
                  child: child,
                );
              } else {
                final slideIn = Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOutCubic));
                final scaleIn = Tween<double>(
                  begin: 0.96,
                  end: 1.0,
                ).chain(CurveTween(curve: Curves.easeOutCubic));
                final fadeIn = Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).chain(CurveTween(curve: Curves.easeIn));
                return FadeTransition(
                  opacity: animation.drive(fadeIn),
                  child: ScaleTransition(
                    scale: animation.drive(scaleIn),
                    child: SlideTransition(
                      position: animation.drive(slideIn),
                      child: child,
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.uri}',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    ),
  );
}

/// Bridges GetX Rx observables → ChangeNotifier for go_router's refreshListenable.
class _GetxRefreshListenable extends ChangeNotifier {
  final List<RxInterface> _observables;
  final List<Worker> _workers = [];

  _GetxRefreshListenable(this._observables) {
    for (final obs in _observables) {
      _workers.add(ever(obs, (_) => notifyListeners()));
    }
  }

  @override
  void dispose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.dispose();
  }
}
