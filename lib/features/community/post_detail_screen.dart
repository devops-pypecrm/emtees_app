import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/phase3.dart';
import '../auth/auth_provider.dart';
import 'community_provider.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({required this.post, super.key});

  final CommunityPost post;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _loading = true;
  bool _sending = false;
  String? _error;
  List<CommunityComment> _comments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final comments =
          await ref.read(communityRepositoryProvider).fetchComments(widget.post.id);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load comments.';
      });
    }
  }

  Future<void> _send() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final comment = await ref
          .read(communityRepositoryProvider)
          .addComment(widget.post.id, content: text);
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _commentController.clear();
        _sending = false;
      });
      ref
          .read(communityPostsProvider.notifier)
          .adjustCommentCount(widget.post.id, 1);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not post comment.')));
    }
  }

  Future<void> _deleteComment(CommunityComment comment) async {
    try {
      await ref.read(communityRepositoryProvider).deleteComment(comment.id);
      if (!mounted) return;
      setState(() => _comments.removeWhere((c) => c.id == comment.id));
      ref
          .read(communityPostsProvider.notifier)
          .adjustCommentCount(widget.post.id, -1);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not delete comment.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final scheme = Theme.of(context).colorScheme;
    final currentUserId = ref.watch(authProvider).user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        post.authorName.isNotEmpty
                            ? post.authorName[0].toUpperCase()
                            : '?',
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.authorName,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            post.createdAt != null
                                ? timeago.format(post.createdAt!)
                                : '',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (post.title != null && post.title!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(post.title!, style: Theme.of(context).textTheme.titleLarge),
                ],
                const SizedBox(height: 8),
                Text(post.content),
                const Divider(height: 32),
                Text('Comments (${_comments.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Text(_error!)
                else if (_comments.isEmpty)
                  const Text('No comments yet.')
                else
                  ..._comments.map((comment) {
                    final canDelete = currentUserId != null &&
                        comment.author?['id']?.toString() == currentUserId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: scheme.secondaryContainer,
                            child: Text(
                              comment.authorName.isNotEmpty
                                  ? comment.authorName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  fontSize: 12, color: scheme.onSecondaryContainer),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(comment.authorName,
                                    style:
                                        const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(comment.content),
                              ],
                            ),
                          ),
                          if (canDelete)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => _deleteComment(comment),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _sending
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
