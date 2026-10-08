import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_provider.dart';
import '../features/auth/login_screen.dart';
import '../features/call/call_screen.dart';
import '../features/chat/conversation_screen.dart';
import '../features/chat/conversations_screen.dart';
import '../features/classes/class_detail_screen.dart';
import '../features/classes/home_screen.dart';
import '../features/community/community_feed_screen.dart';
import '../features/discipline/discipline_screen.dart';
import '../features/materials/materials_screen.dart';
import '../features/me/attendance_screen.dart';
import '../features/me/my_batches_screen.dart';
import '../features/me/my_feedback_screen.dart';
import '../features/me/my_payments_screen.dart';
import '../features/me/my_requests_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/performance/performance_screen.dart';
import '../features/profile/change_password_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/updates/update_screen.dart';
import '../models/release_manifest.dart';
import 'main_shell.dart';

/// Exposed so overlay widgets mounted above the Router (e.g. the OTA update
/// dialog) can still obtain a context with a Navigator ancestor.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _AuthRefreshListenable(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final loggingIn = state.matchedLocation == '/login';
      final splashing = state.matchedLocation == '/splash';

      if (authState.status == AuthStatus.unknown) {
        return splashing ? null : '/splash';
      }
      final authenticated = authState.status == AuthStatus.authenticated;
      if (!authenticated && !loggingIn) return '/login';
      if (authenticated && (loggingIn || splashing)) return '/home';
      if (!authenticated && splashing) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/class/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final isOneToOne = state.uri.queryParameters['oneToOne'] == 'true';
          return ClassDetailScreen(id: id, isOneToOne: isOneToOne);
        },
      ),
      GoRoute(
        path: '/call/:roomName',
        builder: (context, state) {
          final roomName = state.pathParameters['roomName']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CallScreen(
            roomName: roomName,
            jwt: extra['jwt'] as String?,
            displayName: extra['displayName'] as String? ?? 'User',
            isModerator: extra['isModerator'] as bool? ?? false,
            oneToOneSessionId: extra['oneToOneSessionId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/chat/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final name = state.extra as String?;
          return ConversationScreen(otherUserId: userId, otherUserName: name);
        },
      ),
      GoRoute(
        path: '/requests',
        builder: (context, state) => const MyRequestsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/batches',
        builder: (context, state) => const MyBatchesScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendanceScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/feedback',
        builder: (context, state) => const MyFeedbackScreen(),
      ),
      GoRoute(
        path: '/payments',
        builder: (context, state) => const MyPaymentsScreen(),
      ),
      GoRoute(
        path: '/performance',
        builder: (context, state) => const PerformanceScreen(),
      ),
      GoRoute(
        path: '/discipline',
        builder: (context, state) => const DisciplineScreen(),
      ),
      GoRoute(
        path: '/update',
        builder: (context, state) {
          final manifest = state.extra as ReleaseManifest;
          return UpdateScreen(manifest: manifest);
        },
      ),
      GoRoute(
        path: '/materials/:batchId',
        builder: (context, state) {
          final batchId = state.pathParameters['batchId']!;
          final name = state.uri.queryParameters['name'] ?? 'Batch';
          return MaterialsScreen(batchId: batchId, batchName: name);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/chat',
              builder: (context, state) => const ConversationsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/community',
              builder: (context, state) => const CommunityFeedScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Bridges Riverpod's authProvider state changes into a Listenable so
/// go_router re-evaluates its redirect whenever auth status changes.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}
