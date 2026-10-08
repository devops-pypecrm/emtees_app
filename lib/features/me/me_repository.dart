import '../../core/api_client.dart';
import '../../models/my_data.dart';
import '../../models/phase3.dart';

class MeRepository {
  MeRepository(this._api);

  final ApiClient _api;

  Future<void> updateProfile({
    required String name,
    String? username,
    String? countryCode,
    String? countryISO,
    String? phoneNumber,
    String? phone,
  }) {
    return _api.putJson('/me/profile', body: {
      'name': name,
      if (username != null) 'username': username,
      if (countryCode != null) 'countryCode': countryCode,
      if (countryISO != null) 'countryISO': countryISO,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (phone != null) 'phone': phone,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _api.postJson('/me/password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': newPassword,
    });
  }

  Future<FeedbackItem> createFeedback({
    required String teacherId,
    required String batchId,
    String? classId,
    required int rating,
    String? comment,
  }) async {
    final data = await _api.postJson('/me/feedback', body: {
      'teacherId': teacherId,
      'batchId': batchId,
      if (classId != null) 'classId': classId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return FeedbackItem.fromJson(data);
  }

  Future<FeedbackItem> updateFeedback(
    String id, {
    int? rating,
    String? comment,
  }) async {
    final data = await _api.putJson('/me/feedback/$id', body: {
      if (rating != null) 'rating': rating,
      if (comment != null) 'comment': comment,
    });
    return FeedbackItem.fromJson(data);
  }

  Future<List<MyBatch>> fetchMyBatches() async {
    final data = await _api.getList('/me/batches');
    return data
        .map((e) => MyBatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchMyPayments() async {
    final data = await _api.getList('/me/payments');
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<MyRequest>> fetchMyRequests() async {
    final data = await _api.getList('/me/requests');
    return data
        .map((e) => MyRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MyRequest> createRequest({
    required String requestType,
    String? fromBatchId,
    String? toBatchId,
    String? reason,
  }) async {
    final data = await _api.postJson('/me/requests', body: {
      'requestType': requestType,
      if (fromBatchId != null) 'fromBatchId': fromBatchId,
      if (toBatchId != null) 'toBatchId': toBatchId,
      if (reason != null) 'reason': reason,
    });
    return MyRequest.fromJson(data);
  }

  Future<void> cancelRequest(String id) =>
      _api.postJson('/me/requests/$id/cancel');

  Future<List<FeedbackItem>> fetchMyFeedback() async {
    final data = await _api.getList('/me/feedback');
    return data
        .whereType<Map>()
        .map((e) => FeedbackItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Shape is loosely defined by the backend (mirrors a tRPC procedure), so
  /// we accept either a bare list or an object wrapping the list under a
  /// few plausible keys.
  Future<List<Map<String, dynamic>>> fetchMyAttendance() async {
    final data = await _api.getDynamic('/me/attendance');
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    if (data is Map) {
      final map = data.cast<String, dynamic>();
      final list = map['items'] ?? map['attendance'] ?? map['records'];
      if (list is List) {
        return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }
    return const [];
  }

  Future<Map<String, dynamic>> fetchSessionSummary() async {
    final data = await _api.getDynamic('/me/session-summary');
    if (data is Map) return data.cast<String, dynamic>();
    return const {};
  }
}
