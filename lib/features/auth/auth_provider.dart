import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../models/user.dart';
import '../chat/chat_provider.dart';
import '../classes/classes_provider.dart';
import '../community/community_provider.dart';
import '../discipline/discipline_provider.dart';
import '../materials/materials_provider.dart';
import '../me/me_provider.dart';
import '../notifications/notifications_provider.dart';
import '../performance/performance_provider.dart';
import '../realtime/socket_service.dart';
import 'auth_repository.dart';

enum AuthStatus { unknown, authenticating, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? error;

  const AuthState({required this.status, this.user, this.error});

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  AuthState copyWith({AuthStatus? status, AppUser? user, String? error}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return AuthRepository(api, storage);
});

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Wire the API client's 401 handler to force logout.
    final api = ref.read(apiClientProvider);
    api.onUnauthorized = () {
      _forceLogout();
    };
    Future.microtask(_restoreSession);
    return const AuthState.unknown();
  }

  Future<void> _restoreSession() async {
    final repo = ref.read(authRepositoryProvider);
    final token = await repo.readToken();
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    // Show cached user immediately for a snappy start, then validate.
    final cached = await repo.readCachedUser();
    if (cached != null) {
      state = AuthState(status: AuthStatus.authenticated, user: cached);
    }
    final fresh = await repo.fetchMe();
    if (fresh == null) {
      await repo.logout();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } else {
      state = AuthState(status: AuthStatus.authenticated, user: fresh);
      ref.read(socketServiceProvider).connect();
    }
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating, error: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.login(username: username, password: password);
      state = AuthState(status: AuthStatus.authenticated, user: result.user);
      ref.read(socketServiceProvider).connect();
    } on ApiException catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        error: e.message,
      );
    } catch (_) {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Unable to sign in. Please try again.',
      );
    }
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    ref.read(socketServiceProvider).disconnect();
    _invalidateSessionData();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Clears every provider that caches data scoped to the signed-in account
  /// (classes/schedule, chat, notifications, batches, requests, feedback,
  /// payments, community, discipline, performance, materials, profile-edit
  /// forms). Without this, logging out and back in as a different account
  /// — or even the same one — kept showing stale data from the previous
  /// session until each screen happened to be manually refreshed.
  void _invalidateSessionData() {
    ref.invalidate(scheduleProvider);
    ref.invalidate(conversationsProvider);
    ref.invalidate(notificationsProvider);
    ref.invalidate(myBatchesProvider);
    ref.invalidate(myRequestsProvider);
    ref.invalidate(myFeedbackProvider);
    ref.invalidate(myPaymentsProvider);
    ref.invalidate(profileEditProvider);
    ref.invalidate(passwordChangeProvider);
    ref.invalidate(communityPostsProvider);
    ref.invalidate(disciplineProvider);
    ref.invalidate(performanceProvider);
    ref.invalidate(materialsProvider);
  }

  /// Re-fetches the current user (e.g. after a profile edit) and updates
  /// the cached/in-memory state without disturbing auth status.
  Future<void> refreshUser() async {
    if (state.status != AuthStatus.authenticated) return;
    final repo = ref.read(authRepositoryProvider);
    final fresh = await repo.fetchMe();
    if (fresh != null) {
      state = state.copyWith(status: AuthStatus.authenticated, user: fresh);
    }
  }

  void _forceLogout() {
    ref.read(socketServiceProvider).disconnect();
    _invalidateSessionData();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      error: 'Your session has expired. Please sign in again.',
    );
  }
}
