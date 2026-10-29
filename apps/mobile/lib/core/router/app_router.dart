import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../../features/admin/events/presentation/admin_event_detail_screen.dart';
import '../../features/admin/events/presentation/admin_event_form_screen.dart';
import '../../features/admin/events/presentation/admin_event_list_screen.dart';
import '../../features/admin/scanner/presentation/scanner_screen.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/user/checkin/presentation/checkin_screen.dart';
import '../../features/user/events/presentation/event_detail_screen.dart';
import '../../features/user/events/presentation/event_list_screen.dart';
import '../../features/user/history/presentation/history_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;

      if (!auth.initialized) {
        return location == '/splash' ? null : '/splash';
      }
      if (!auth.isAuthenticated) {
        return location == '/login' || location == '/register'
            ? null
            : '/login';
      }
      if (auth.mustChangePassword) {
        return location == '/change-password' ? null : '/change-password';
      }
      if (location == '/login' ||
          location == '/register' ||
          location == '/splash' ||
          location == '/') {
        return auth.isAdmin ? '/scanner' : '/events';
      }
      if (auth.isAdmin) {
        final allowed =
            location == '/scanner' ||
            location == '/profile' ||
            location.startsWith('/manage-events');
        return allowed ? null : '/scanner';
      }
      if (location == '/scanner' || location.startsWith('/manage-events')) {
        return '/events';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/scanner',
        builder: (context, state) => const ScannerScreen(),
      ),
      GoRoute(
        path: '/manage-events',
        builder: (context, state) => const AdminEventListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const AdminEventFormScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                AdminEventDetailScreen(eventId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) =>
                    AdminEventFormScreen(eventId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/events',
        builder: (context, state) => const EventListScreen(),
      ),
      GoRoute(
        path: '/events/:id',
        builder: (context, state) =>
            EventDetailScreen(eventId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'checkin',
            builder: (context, state) =>
                CheckinScreen(eventId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text('No route for ${state.uri}')),
    ),
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bluetooth_searching, size: 56),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
