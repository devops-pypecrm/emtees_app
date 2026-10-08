import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/main_shell.dart';
import '../../models/phase3.dart';
import '../auth/auth_provider.dart';
import '../me/me_provider.dart';
import 'community_provider.dart';
import 'post_detail_screen.dart';

class CommunityFeedScreen extends ConsumerWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityPostsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () =>
              ref.read(mainScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: const Text('Community'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCompose(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(communityPostsProvider.notifier).refresh(),
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, AsyncListState<CommunityPost> state) {
    if (state.loading && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(4, (_) => const _SkeletonCard()),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return _CenteredMessage(icon: Icons.error_outline, message: state.error!);
    }
    if (state.items.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.forum_outlined,
        message: 'No posts yet. Be the first to share something!',
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 96),
      itemCount: state.items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _PostCard(post: state.items[index]),
      ),
    );
  }

  void _openCompose(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ComposePostSheet(),
    );
  }
}

class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});

  final CommunityPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).user;
    final canDelete = user != null &&
        (post.author?['id']?.toString() == user.id || user.isStaff || user.isTeacher);

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                              : (post.authorRole ?? ''),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (post.isPinned)
                    const Icon(Icons.push_pin, size: 16, color: Colors.orange),
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _confirmDelete(context, ref),
                    ),
                ],
              ),
              if (post.title != null && post.title!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(post.title!,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 6),
              Text(post.content, maxLines: 5, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      post.isLiked ? Icons.favorite : Icons.favorite_border,
                      color: post.isLiked ? Colors.red : null,
                      size: 20,
                    ),
                    onPressed: () =>
                        ref.read(communityPostsProvider.notifier).toggleLike(post.id),
                  ),
                  Text('${post.likesCount}'),
                  const SizedBox(width: 16),
                  const Icon(Icons.mode_comment_outlined, size: 18),
                  const SizedBox(width: 4),
                  Text('${post.commentsCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(communityPostsProvider.notifier).deletePost(post.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ComposePostSheet extends ConsumerStatefulWidget {
  const _ComposePostSheet();

  @override
  ConsumerState<_ComposePostSheet> createState() => _ComposePostSheetState();
}

class _ComposePostSheetState extends ConsumerState<_ComposePostSheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _mediaController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _mediaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_contentController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final ok = await ref.read(communityPostsProvider.notifier).createPost(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          mediaUrl: _mediaController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not publish post.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Post', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'What do you want to share?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mediaController,
              decoration: const InputDecoration(
                labelText: 'Media link (optional)',
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
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
