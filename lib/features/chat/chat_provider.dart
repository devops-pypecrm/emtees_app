import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/chat.dart';
import '../auth/auth_provider.dart';
import '../realtime/socket_service.dart';
import 'chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});

class ConversationsState {
  final bool loading;
  final String? error;
  final List<Conversation> conversations;

  const ConversationsState({
    this.loading = false,
    this.error,
    this.conversations = const [],
  });

  int get totalUnread =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);

  ConversationsState copyWith({
    bool? loading,
    String? error,
    List<Conversation>? conversations,
  }) {
    return ConversationsState(
      loading: loading ?? this.loading,
      error: error,
      conversations: conversations ?? this.conversations,
    );
  }
}

final conversationsProvider =
    NotifierProvider<ConversationsNotifier, ConversationsState>(
  ConversationsNotifier.new,
);

class ConversationsNotifier extends Notifier<ConversationsState> {
  @override
  ConversationsState build() {
    ref.listen(realtimeEventsProvider, (previous, next) {
      final event = next.valueOrNull;
      if (event != null && event.type == 'private_message:new') {
        refresh();
      }
    });
    Future.microtask(refresh);
    return const ConversationsState(loading: true);
  }

  Future<void> refresh() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final conversations = await repo.fetchConversations();
      conversations.sort((a, b) {
        final at = a.lastMessageTime;
        final bt = b.lastMessageTime;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      });
      state = ConversationsState(conversations: conversations);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load conversations. Pull to refresh to try again.',
      );
    }
  }

  /// Locally zero out unread count for a conversation once it's opened
  /// (the backend marks it read server-side when messages are fetched).
  void markConversationRead(String otherUserId) {
    state = state.copyWith(
      conversations: [
        for (final c in state.conversations)
          if (c.otherUser.id == otherUserId) c.copyWith(unreadCount: 0) else c,
      ],
    );
  }
}
