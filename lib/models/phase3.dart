// Models for phase-3 features: feedback, materials, performance,
// discipline and community. Parsed defensively since several backend
// shapes are loosely specified.

Map<String, dynamic>? _asMap(dynamic v) =>
    v is Map<String, dynamic> ? v : (v is Map ? v.cast<String, dynamic>() : null);

DateTime? _asDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class FeedbackItem {
  final String id;
  final String teacherId;
  final String batchId;
  final String? classId;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final Map<String, dynamic>? teacher;
  final Map<String, dynamic>? batch;
  final Map<String, dynamic>? classInfo;

  FeedbackItem({
    required this.id,
    required this.teacherId,
    required this.batchId,
    this.classId,
    required this.rating,
    this.comment,
    this.createdAt,
    this.teacher,
    this.batch,
    this.classInfo,
  });

  String get teacherName => teacher?['name'] as String? ?? 'Teacher';
  String get batchName =>
      batch?['name'] as String? ?? batch?['title'] as String? ?? 'Batch';

  factory FeedbackItem.fromJson(Map<String, dynamic> json) {
    return FeedbackItem(
      id: (json['id'] ?? '').toString(),
      teacherId: (json['teacherId'] ?? '').toString(),
      batchId: (json['batchId'] ?? '').toString(),
      classId: json['classId']?.toString(),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      createdAt: _asDate(json['createdAt']),
      teacher: _asMap(json['teacher']),
      batch: _asMap(json['batch']),
      classInfo: _asMap(json['class']),
    );
  }
}

class LearningMaterial {
  final String id;
  final String batchId;
  final String title;
  final String? description;
  final String type;
  final String? contentUrl;
  final DateTime? scheduledDate;
  final DateTime? createdAt;

  LearningMaterial({
    required this.id,
    required this.batchId,
    required this.title,
    this.description,
    required this.type,
    this.contentUrl,
    this.scheduledDate,
    this.createdAt,
  });

  factory LearningMaterial.fromJson(Map<String, dynamic> json) {
    return LearningMaterial(
      id: (json['id'] ?? '').toString(),
      batchId: (json['batchId'] ?? '').toString(),
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String?,
      type: json['type'] as String? ?? 'text',
      contentUrl: json['contentUrl'] as String?,
      scheduledDate: _asDate(json['scheduledDate']),
      createdAt: _asDate(json['createdAt']),
    );
  }
}

class PerformanceReport {
  final String id;
  final Map<String, dynamic> raw;

  PerformanceReport({required this.id, required this.raw});

  String get title =>
      raw['title'] as String? ??
      raw['reportTitle'] as String? ??
      raw['assessmentPeriod'] as String? ??
      'Performance Report';

  String? get summary =>
      raw['summary'] as String? ??
      raw['comments'] as String? ??
      raw['remarks'] as String? ??
      raw['description'] as String?;

  String? get status => raw['status'] as String?;

  String? get assessmentPeriod => raw['assessmentPeriod'] as String?;

  Map<String, dynamic>? get targetUser => _asMap(raw['targetUser']);

  String? get targetUserName => targetUser?['name'] as String?;

  DateTime? get createdAt => _asDate(raw['createdAt']);

  factory PerformanceReport.fromJson(Map<String, dynamic> json) {
    return PerformanceReport(id: (json['id'] ?? '').toString(), raw: json);
  }
}

class DisciplineRecord {
  final String id;
  final Map<String, dynamic> raw;

  DisciplineRecord({required this.id, required this.raw});

  String get level => raw['level'] as String? ?? 'Warning';
  String? get reason => raw['reason'] as String?;
  String? get description => raw['description'] as String?;
  String? get status => raw['status'] as String?;
  DateTime? get createdAt => _asDate(raw['createdAt']);
  Map<String, dynamic>? get user => _asMap(raw['user']);
  Map<String, dynamic>? get reporter => _asMap(raw['reporter']);
  String? get userName => user?['name'] as String?;
  String? get reporterName => reporter?['name'] as String?;

  factory DisciplineRecord.fromJson(Map<String, dynamic> json) {
    return DisciplineRecord(id: (json['id'] ?? '').toString(), raw: json);
  }
}

class CommunityPost {
  final String id;
  final String? title;
  final String content;
  final String? mediaUrl;
  final String? mediaName;
  final Map<String, dynamic>? author;
  final int likesCount;
  final bool isLiked;
  final int commentsCount;
  final DateTime? createdAt;
  final bool isPinned;

  CommunityPost({
    required this.id,
    this.title,
    required this.content,
    this.mediaUrl,
    this.mediaName,
    this.author,
    this.likesCount = 0,
    this.isLiked = false,
    this.commentsCount = 0,
    this.createdAt,
    this.isPinned = false,
  });

  String get authorName => author?['name'] as String? ?? 'Someone';
  String? get authorRole => author?['role'] as String?;

  CommunityPost copyWith({int? likesCount, bool? isLiked, int? commentsCount}) {
    return CommunityPost(
      id: id,
      title: title,
      content: content,
      mediaUrl: mediaUrl,
      mediaName: mediaName,
      author: author,
      likesCount: likesCount ?? this.likesCount,
      isLiked: isLiked ?? this.isLiked,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt,
      isPinned: isPinned,
    );
  }

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: (json['id'] ?? '').toString(),
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String?,
      mediaName: json['mediaName'] as String?,
      author: _asMap(json['author']),
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      isLiked: json['isLiked'] as bool? ?? false,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      createdAt: _asDate(json['createdAt']),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }
}

class CommunityComment {
  final String id;
  final String content;
  final Map<String, dynamic>? author;
  final String? parentId;
  final DateTime? createdAt;

  CommunityComment({
    required this.id,
    required this.content,
    this.author,
    this.parentId,
    this.createdAt,
  });

  String get authorName => author?['name'] as String? ?? 'Someone';

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      id: (json['id'] ?? '').toString(),
      content: json['content'] as String? ?? '',
      author: _asMap(json['author']),
      parentId: json['parentId']?.toString(),
      createdAt: _asDate(json['createdAt']),
    );
  }
}
