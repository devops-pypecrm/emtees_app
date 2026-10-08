import '../../core/api_client.dart';
import '../../models/phase3.dart';

class CommunityRepository {
  CommunityRepository(this._api);

  final ApiClient _api;

  Future<List<CommunityPost>> fetchPosts() async {
    final data = await _api.getList('/community/posts');
    return data
        .whereType<Map>()
        .map((e) => CommunityPost.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<CommunityPost> createPost({
    String? title,
    required String content,
    String? mediaUrl,
    String? mediaName,
  }) async {
    final data = await _api.postJson('/community/posts', body: {
      if (title != null && title.isNotEmpty) 'title': title,
      'content': content,
      if (mediaUrl != null && mediaUrl.isNotEmpty) 'mediaUrl': mediaUrl,
      if (mediaName != null && mediaName.isNotEmpty) 'mediaName': mediaName,
    });
    return CommunityPost.fromJson(data);
  }

  Future<void> deletePost(String id) => _api.deleteJson('/community/posts/$id');

  Future<bool> toggleLike(String id) async {
    final data = await _api.postJson('/community/posts/$id/like');
    return data['liked'] as bool? ?? false;
  }

  Future<List<CommunityComment>> fetchComments(String postId) async {
    final data = await _api.getList('/community/posts/$postId/comments');
    return data
        .whereType<Map>()
        .map((e) => CommunityComment.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<CommunityComment> addComment(
    String postId, {
    required String content,
    String? parentId,
  }) async {
    final data = await _api.postJson('/community/posts/$postId/comments', body: {
      'content': content,
      if (parentId != null) 'parentId': parentId,
    });
    return CommunityComment.fromJson(data);
  }

  Future<void> deleteComment(String id) =>
      _api.deleteJson('/community/comments/$id');
}
