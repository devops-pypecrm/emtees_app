import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/chat.dart';
import '../auth/auth_provider.dart';
import '../realtime/socket_service.dart';
import 'chat_provider.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.otherUserId,
    this.otherUserName,
  });

  final String otherUserId;
  final String? otherUserName;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(chatRepositoryProvider);
      final messages = await repo.fetchMessagesWith(widget.otherUserId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      ref
          .read(conversationsProvider.notifier)
          .markConversationRead(widget.otherUserId);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this conversation.';
      });
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _messageController.clear();
    try {
      final repo = ref.read(chatRepositoryProvider);
      final message = await repo.sendMessage(
        receiverId: widget.otherUserId,
        content: text,
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _sending = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      ref.read(conversationsProvider.notifier).refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message.')),
      );
      _messageController.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;

    ref.listen(realtimeEventsProvider, (previous, next) {
      final event = next.valueOrNull;
      if (event == null || event.type != 'private_message:new') return;
      final senderId = event.payload['senderId']?.toString();
      if (senderId == widget.otherUserId) {
        _load();
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherUserName ?? 'Conversation')),
      body: Column(
        children: [
          Expanded(child: _buildMessages(currentUser?.id)),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessages(String? currentUserId) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(child: Text('Say hello 👋'));
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMine = message.senderId == currentUserId;
        return _MessageBubble(message: message, isMine: isMine);
      },
    );
  }

  Widget _buildInputBar() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = _contentFor(message);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content,
              style: TextStyle(
                color: isMine ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
            if (message.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('h:mm a').format(message.createdAt!.toLocal()),
                style: TextStyle(
                  fontSize: 10,
                  color: (isMine ? scheme.onPrimary : scheme.onSurface)
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _contentFor(ChatMessage message) {
    switch (message.type) {
      case 'voice':
        return '🎤 Voice message';
      case 'image':
        return '📷 Image';
      case 'video':
        return '🎬 Video';
      case 'pdf':
        return '📄 Document';
      default:
        return message.content;
    }
  }
}
