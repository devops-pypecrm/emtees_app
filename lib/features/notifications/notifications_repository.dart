import '../../core/api_client.dart';
import '../../models/notification_item.dart';

class NotificationsPage {
  final List<NotificationItem> items;
  final String? nextCursor;
  NotificationsPage({required this.items, this.nextCursor});
}

class NotificationsRepository {
  NotificationsRepository(this._api);

  final ApiClient _api;

  Future<NotificationsPage> fetchNotifications({
    String? cursor,
    int limit = 20,
  }) async {
    final query = <String, dynamic>{'limit': limit};
    if (cursor != null) query['cursor'] = cursor;
    final data = await _api.getJson('/notifications', query: query);
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return NotificationsPage(
      items: items,
      nextCursor: data['nextCursor']?.toString(),
    );
  }

  Future<void> markRead(String id) =>
      _api.postJson('/notifications/$id/read');

  Future<void> markAllRead() => _api.postJson('/notifications/read-all');

  Future<void> delete(String id) => _api.deleteJson('/notifications/$id');

  Future<void> dismissAnnouncement(String id) =>
      _api.postJson('/notifications/announcements/$id/dismiss');
}
