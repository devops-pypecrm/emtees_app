import 'class_item.dart';

class OneToOneSession {
  final String id;
  final String teacherId;
  final String studentId;
  final String title;
  final int? sessionLength;
  final DateTime? scheduledAt;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? meetingUrl;
  final String? recordingUrl;
  final ClassPersonRef? teacher;
  final ClassPersonRef? student;

  OneToOneSession({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.title,
    this.sessionLength,
    this.scheduledAt,
    required this.status,
    this.startedAt,
    this.endedAt,
    this.meetingUrl,
    this.recordingUrl,
    this.teacher,
    this.student,
  });

  bool get isLive => status == 'live';
  bool get isScheduled =>
      status == 'scheduled' || status == 'reschedule_request_pending';
  bool get isPast => status == 'completed' || status == 'cancelled';

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  factory OneToOneSession.fromJson(Map<String, dynamic> json) {
    return OneToOneSession(
      id: json['id'].toString(),
      teacherId: (json['teacherId'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      title: json['title'] as String? ?? '1:1 Session',
      sessionLength: json['sessionLength'] is int
          ? json['sessionLength'] as int
          : int.tryParse('${json['sessionLength']}'),
      scheduledAt: _parseDate(json['scheduledAt']),
      status: json['status'] as String? ?? 'scheduled',
      startedAt: _parseDate(json['startedAt']),
      endedAt: _parseDate(json['endedAt']),
      meetingUrl: json['meetingUrl'] as String?,
      recordingUrl: json['recordingUrl'] as String?,
      teacher: json['teacher'] is Map<String, dynamic>
          ? ClassPersonRef.fromJson(json['teacher'] as Map<String, dynamic>)
          : null,
      student: json['student'] is Map<String, dynamic>
          ? ClassPersonRef.fromJson(json['student'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Result of POST /one-to-one/:id/start — {success, jwt, roomName, isModerator}.
/// Also used for POST /one-to-one/:id/join, which lets the assigned teacher,
/// assigned student, or a super_admin fetch a join JWT for a 1:1 session.
class OneToOneMeetingResult {
  final String? jwt;
  final String roomName;
  final bool isModerator;

  OneToOneMeetingResult({
    this.jwt,
    required this.roomName,
    required this.isModerator,
  });

  factory OneToOneMeetingResult.fromJson(Map<String, dynamic> json) {
    return OneToOneMeetingResult(
      jwt: json['jwt'] as String?,
      roomName: json['roomName'] as String? ?? '',
      isModerator: json['isModerator'] as bool? ?? true,
    );
  }
}

class InstantSessionResult {
  final OneToOneSession session;
  final String? jwt;
  final bool isModerator;

  InstantSessionResult({
    required this.session,
    this.jwt,
    required this.isModerator,
  });

  factory InstantSessionResult.fromJson(Map<String, dynamic> json) {
    return InstantSessionResult(
      session: OneToOneSession.fromJson(json),
      jwt: json['jwt'] as String?,
      isModerator: json['isModerator'] as bool? ?? true,
    );
  }
}
