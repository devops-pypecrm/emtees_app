import '../../core/api_client.dart';
import '../../models/class_item.dart';
import '../../models/one_to_one_session.dart';

class ClassesRepository {
  ClassesRepository(this._api);

  final ApiClient _api;

  Future<List<ClassItem>> fetchClasses({
    String? batchId,
    String? status,
    int? limit,
  }) async {
    final query = <String, dynamic>{};
    if (batchId != null) query['batchId'] = batchId;
    if (status != null) query['status'] = status;
    if (limit != null) query['limit'] = limit;
    final data = await _api.getList('/classes', query: query);
    return data
        .map((e) => ClassItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<OneToOneSession>> fetchOneToOne({
    String? studentId,
    String? teacherId,
  }) async {
    final query = <String, dynamic>{};
    if (studentId != null) query['studentId'] = studentId;
    if (teacherId != null) query['teacherId'] = teacherId;
    final data = await _api.getList('/one-to-one', query: query);
    return data
        .map((e) => OneToOneSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MeetingDetails> getMeetingDetails(String classId) async {
    final data = await _api.getJson('/classes/$classId/meeting');
    return MeetingDetails.fromJson(data);
  }

  Future<void> startClass(String classId) =>
      _api.postJson('/classes/$classId/start');

  Future<void> endClass(String classId) =>
      _api.postJson('/classes/$classId/end');

  Future<JoinStatus> getJoinStatus(String classId) async {
    final data = await _api.getJson('/classes/$classId/join-status');
    return JoinStatus.fromJson(data);
  }

  Future<void> requestToJoin(String classId) =>
      _api.postJson('/classes/$classId/join-requests');

  Future<List<JoinRequest>> getJoinRequests(String classId) async {
    final data = await _api.getList('/classes/$classId/join-requests');
    return data
        .map((e) => JoinRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> approveJoinRequest(String classId, String studentId) =>
      _api.postJson('/classes/$classId/join-requests/$studentId/approve');

  Future<void> declineJoinRequest(String classId, String studentId) =>
      _api.postJson('/classes/$classId/join-requests/$studentId/decline');

  Future<void> approveAllJoinRequests(String classId) =>
      _api.postJson('/classes/$classId/join-requests/approve-all');

  Future<OneToOneMeetingResult> startOneToOne(String sessionId) async {
    final data = await _api.postJson('/one-to-one/$sessionId/start');
    return OneToOneMeetingResult.fromJson(data);
  }

  Future<InstantSessionResult> startInstantOneToOne({
    required String studentId,
    int? sessionLength,
    String? remarks,
  }) async {
    final data = await _api.postJson('/one-to-one/instant', body: {
      'studentId': studentId,
      if (sessionLength != null) 'sessionLength': sessionLength,
      if (remarks != null) 'remarks': remarks,
    });
    return InstantSessionResult.fromJson(data);
  }

  Future<OneToOneMeetingResult> joinOneToOne(String sessionId) async {
    final data = await _api.postJson('/one-to-one/$sessionId/join');
    return OneToOneMeetingResult.fromJson(data);
  }

  Future<void> sendHeartbeat(String sessionId, {bool? bothPresent}) =>
      _api.postJson('/one-to-one/$sessionId/heartbeat', body: {
        if (bothPresent != null) 'bothPresent': bothPresent,
      });
}
