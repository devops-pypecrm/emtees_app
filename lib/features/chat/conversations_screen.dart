import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/main_shell.dart';
import '../../models/chat.dart';
import 'chat_provider.dart';
import 'new_conversation_screen.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () =>
              ref.read(mainScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: const Text('Messages'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
        child: _buildBody(context, state),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NewConversationScreen()),
        ),
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ConversationsState state) {
    if (state.loading && state.conversations.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => const _SkeletonTile(),
      );
    }

    if (state.error != null && state.conversations.isEmpty) {
      return _CenteredMessage(
        icon: Icons.error_outline,
        message: state.error!,
      );
    }

    if (state.conversations.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.chat_bubble_outline,
        message: 'No conversations yet.\nTap the pencil icon to start one.',
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: state.conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final convo = state.conversations[index];
        return _ConversationTile(convo: convo);
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.convo});

  final Conversation convo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = _previewFor(convo);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          convo.otherUser.name.isNotEmpty
              ? convo.otherUser.name[0].toUpperCase()
              : '?',
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
      ),
      title: Text(
        convo.otherUser.name,
        style: TextStyle(
          fontWeight: convo.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: convo.unreadCount > 0
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
          fontWeight: convo.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (convo.lastMessageTime != null)
            Text(
              timeago.format(convo.lastMessageTime!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (convo.unreadCount > 0) ...[
            const SizedBox(height: 6),
            CircleAvatar(
              radius: 10,
              backgroundColor: scheme.primary,
              child: Text(
                '${convo.unreadCount > 9 ? '9+' : convo.unreadCount}',
                style: TextStyle(fontSize: 10, color: scheme.onPrimary),
              ),
            ),
          ],
        ],
      ),
      onTap: () => context.push(
        '/chat/${convo.otherUser.id}',
        extra: convo.otherUser.name,
      ),
    );
  }

  String _previewFor(Conversation convo) {
    switch (convo.lastMessageType) {
      case 'voice':
        return '🎤 Voice message';
      case 'image':
        return '📷 Image';
      case 'video':
        return '🎬 Video';
      case 'pdf':
        return '📄 Document';
      default:
        return convo.lastMessage ?? '';
    }
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
