import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/phase3.dart';
import '../me/me_provider.dart';
import 'community_repository.dart';

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(ref.watch(apiClientProvider));
});

final communityPostsProvider =
    NotifierProvider<CommunityPostsNotifier, AsyncListState<CommunityPost>>(
  CommunityPostsNotifier.new,
);

class CommunityPostsNotifier extends Notifier<AsyncListState<CommunityPost>> {
  @override
  AsyncListState<CommunityPost> build() {
    Future.microtask(refresh);
    return const AsyncListState(loading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await ref.read(communityRepositoryProvider).fetchPosts();
      state = AsyncListState(items: items);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load the community feed. Pull to refresh to try again.',
      );
    }
  }

  Future<bool> createPost({
    String? title,
    required String content,
    String? mediaUrl,
  }) async {
    try {
      final post = await ref.read(communityRepositoryProvider).createPost(
            title: title,
            content: content,
            mediaUrl: mediaUrl,
          );
      state = AsyncListState(items: [post, ...state.items]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleLike(String id) async {
    final index = state.items.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final post = state.items[index];
    // Optimistic update.
    final optimistic = post.copyWith(
      isLiked: !post.isLiked,
      likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
    );
    final updated = [...state.items];
    updated[index] = optimistic;
    state = state.copyWith(items: updated);
    try {
      final liked = await ref.read(communityRepositoryProvider).toggleLike(id);
      final reconciled = [...state.items];
      final idx = reconciled.indexWhere((p) => p.id == id);
      if (idx != -1) {
        final current = reconciled[idx];
        reconciled[idx] = current.copyWith(isLiked: liked);
        state = state.copyWith(items: reconciled);
      }
    } catch (_) {
      // Revert on failure.
      final reverted = [...state.items];
      final idx = reverted.indexWhere((p) => p.id == id);
      if (idx != -1) {
        reverted[idx] = post;
        state = state.copyWith(items: reverted);
      }
    }
  }

  Future<bool> deletePost(String id) async {
    try {
      await ref.read(communityRepositoryProvider).deletePost(id);
      state = state.copyWith(
        items: state.items.where((p) => p.id != id).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void adjustCommentCount(String postId, int delta) {
    final index = state.items.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    final updated = [...state.items];
    updated[index] = updated[index]
        .copyWith(commentsCount: updated[index].commentsCount + delta);
    state = state.copyWith(items: updated);
  }
}
