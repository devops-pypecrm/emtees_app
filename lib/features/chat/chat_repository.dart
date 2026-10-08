import '../../core/api_client.dart';
import '../../models/chat.dart';

class ChatRepository {
  ChatRepository(this._api);

  final ApiClient _api;

  Future<List<Conversation>> fetchConversations() async {
    final data = await _api.getList('/messages/conversations');
    return data
        .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChatContact>> fetchContacts({String? search}) async {
    final query = <String, dynamic>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    final data = await _api.getList('/messages/contacts', query: query);
    return data
        .map((e) => ChatContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ChatMessage>> fetchMessagesWith(
    String userId, {
    int? limit,
    int? offset,
  }) async {
    final query = <String, dynamic>{};
    if (limit != null) query['limit'] = limit;
    if (offset != null) query['offset'] = offset;
    final data = await _api.getList('/messages/with/$userId', query: query);
    return data
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessage> sendMessage({
    required String receiverId,
    required String content,
    String type = 'text',
    String? mediaUrl,
  }) async {
    final data = await _api.postJson('/messages', body: {
      'receiverId': receiverId,
      'content': content,
      'type': type,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
    });
    return ChatMessage.fromJson(data);
  }
}
