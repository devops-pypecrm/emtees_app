import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/notification_item.dart';
import 'notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(apiClientProvider));
});

class NotificationsState {
  final bool loading;
  final bool loadingMore;
  final String? error;
  final List<NotificationItem> items;
  final String? nextCursor;
  final bool initialized;

  const NotificationsState({
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.items = const [],
    this.nextCursor,
    this.initialized = false,
  });

  int get unreadCount => items.where((n) => !n.isRead).length;
  bool get hasMore => nextCursor != null;

  NotificationsState copyWith({
    bool? loading,
    bool? loadingMore,
    String? error,
    List<NotificationItem>? items,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? initialized,
  }) {
    return NotificationsState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: error,
      items: items ?? this.items,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      initialized: initialized ?? this.initialized,
    );
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, NotificationsState>(
  NotificationsNotifier.new,
);

class NotificationsNotifier extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    Future.microtask(refresh);
    return const NotificationsState(loading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final page = await repo.fetchNotifications();
      state = NotificationsState(
        items: page.items,
        nextCursor: page.nextCursor,
        initialized: true,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load notifications. Pull to refresh to try again.',
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final page = await repo.fetchNotifications(cursor: state.nextCursor);
      state = state.copyWith(
        loadingMore: false,
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        clearNextCursor: page.nextCursor == null,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> markRead(NotificationItem item) async {
    if (item.isRead) return;
    state = state.copyWith(
      items: [
        for (final n in state.items)
          if (n.id == item.id) n.copyWith(isRead: true) else n,
      ],
    );
    try {
      await ref.read(notificationsRepositoryProvider).markRead(item.id);
    } catch (_) {
      // Best-effort; local state already updated for responsiveness.
    }
  }

  Future<void> markAllRead() async {
    final previous = state.items;
    state = state.copyWith(
      items: [for (final n in state.items) n.copyWith(isRead: true)],
    );
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }

  Future<void> delete(NotificationItem item) async {
    final previous = state.items;
    state = state.copyWith(
      items: state.items.where((n) => n.id != item.id).toList(),
    );
    try {
      await ref.read(notificationsRepositoryProvider).delete(item.id);
    } catch (_) {
      state = state.copyWith(items: previous);
    }
  }
}
