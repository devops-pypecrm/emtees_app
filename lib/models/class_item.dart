class ClassPersonRef {
  final String id;
  final String name;

  ClassPersonRef({required this.id, required this.name});

  factory ClassPersonRef.fromJson(Map<String, dynamic> json) {
    return ClassPersonRef(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
    );
  }
}

class ClassBatchRef {
  final String id;
  final String name;

  ClassBatchRef({required this.id, required this.name});

  factory ClassBatchRef.fromJson(Map<String, dynamic> json) {
    return ClassBatchRef(
      id: (json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
    );
  }
}

/// A scheduled/live/completed group class.
class ClassItem {
  final String id;
  final String batchId;
  final String teacherId;
  final String title;
  final String? description;
  final String classType; // group | one_to_one
  final String status; // scheduled | live | completed | cancelled
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? duration;
  final String? meetingUrl;
  final String? recordingUrl;
  final ClassPersonRef? teacher;
  final ClassPersonRef? student;
  final ClassBatchRef? batch;
  final bool isEnrolled;
  final String? enrollmentStatus;
  final bool enrollmentAllowed;
  final int assignedStudentsCount;

  ClassItem({
    required this.id,
    required this.batchId,
    required this.teacherId,
    required this.title,
    this.description,
    required this.classType,
    required this.status,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.duration,
    this.meetingUrl,
    this.recordingUrl,
    this.teacher,
    this.student,
    this.batch,
    this.isEnrolled = false,
    this.enrollmentStatus,
    this.enrollmentAllowed = true,
    this.assignedStudentsCount = 0,
  });

  bool get isLive => status == 'live';
  bool get isScheduled => status == 'scheduled';
  bool get isPast => status == 'completed' || status == 'cancelled';

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  factory ClassItem.fromJson(Map<String, dynamic> json) {
    return ClassItem(
      id: json['id'].toString(),
      batchId: (json['batchId'] ?? '').toString(),
      teacherId: (json['teacherId'] ?? '').toString(),
      title: json['title'] as String? ?? 'Untitled class',
      description: json['description'] as String?,
      classType: json['classType'] as String? ?? 'group',
      status: json['status'] as String? ?? 'scheduled',
      scheduledAt: _parseDate(json['scheduledAt']),
      startedAt: _parseDate(json['startedAt']),
      endedAt: _parseDate(json['endedAt']),
      duration: json['duration'] is int
          ? json['duration'] as int
          : int.tryParse('${json['duration']}'),
      meetingUrl: json['meetingUrl'] as String?,
      recordingUrl: json['recordingUrl'] as String?,
      teacher: json['teacher'] is Map<String, dynamic>
          ? ClassPersonRef.fromJson(json['teacher'] as Map<String, dynamic>)
          : null,
      student: json['student'] is Map<String, dynamic>
          ? ClassPersonRef.fromJson(json['student'] as Map<String, dynamic>)
          : null,
      batch: json['batch'] is Map<String, dynamic>
          ? ClassBatchRef.fromJson(json['batch'] as Map<String, dynamic>)
          : null,
      isEnrolled: json['isEnrolled'] as bool? ?? false,
      enrollmentStatus: json['enrollmentStatus'] as String?,
      enrollmentAllowed: json['enrollmentAllowed'] as bool? ?? true,
      assignedStudentsCount: json['assignedStudentsCount'] is int
          ? json['assignedStudentsCount'] as int
          : int.tryParse('${json['assignedStudentsCount'] ?? 0}') ?? 0,
    );
  }
}

class MeetingDetails {
  final String classId;
  final String roomName;
  final String? jwt;
  final bool isModerator;
  final String title;
  final DateTime? scheduledAt;
  final String? teacherName;

  MeetingDetails({
    required this.classId,
    required this.roomName,
    this.jwt,
    required this.isModerator,
    required this.title,
    this.scheduledAt,
    this.teacherName,
  });

  factory MeetingDetails.fromJson(Map<String, dynamic> json) {
    return MeetingDetails(
      classId: json['classId'].toString(),
      roomName: json['roomName'] as String? ?? '',
      jwt: json['jwt'] as String?,
      isModerator: json['isModerator'] as bool? ?? false,
      title: json['title'] as String? ?? 'Class',
      scheduledAt: json['scheduledAt'] != null
          ? DateTime.tryParse(json['scheduledAt'].toString())
          : null,
      teacherName: json['teacherName'] as String?,
    );
  }
}

class JoinStatus {
  final bool isEnrolled;
  final String status; // pending | approved | declined | none
  final String? meetingRoomId;

  JoinStatus({
    required this.isEnrolled,
    required this.status,
    this.meetingRoomId,
  });

  factory JoinStatus.fromJson(Map<String, dynamic> json) {
    return JoinStatus(
      isEnrolled: json['isEnrolled'] as bool? ?? false,
      status: json['status'] as String? ?? 'none',
      meetingRoomId: json['meetingRoomId']?.toString(),
    );
  }
}

class JoinRequest {
  final String id;
  final String classId;
  final String studentId;
  final String status;
  final DateTime? createdAt;
  final String studentName;
  final String? studentUnionId;

  JoinRequest({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.status,
    this.createdAt,
    required this.studentName,
    this.studentUnionId,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    return JoinRequest(
      id: json['id'].toString(),
      classId: (json['classId'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      studentName: json['studentName'] as String? ?? 'Student',
      studentUnionId: json['studentUnionId'] as String?,
    );
  }
}
