/// Loosely-typed model for `/me/batches` entries. Shape differs slightly by
/// role (teacher vs student) so we parse defensively and keep raw fields
/// available for anything not modeled explicitly.
class MyBatch {
  final String id;
  final String? batchId;
  final String? status;
  final Map<String, dynamic>? batch;

  MyBatch({required this.id, this.batchId, this.status, this.batch});

  String get batchName =>
      batch?['name'] as String? ?? batch?['title'] as String? ?? 'Batch';

  String? get moduleName {
    final module = batch?['module'];
    if (module is Map<String, dynamic>) {
      return module['name'] as String? ?? module['title'] as String?;
    }
    return null;
  }

  String? get teacherName {
    final teacher = batch?['teacher'];
    if (teacher is Map<String, dynamic>) {
      return teacher['name'] as String?;
    }
    return null;
  }

  factory MyBatch.fromJson(Map<String, dynamic> json) {
    return MyBatch(
      id: (json['id'] ?? json['batchId'] ?? '').toString(),
      batchId: json['batchId']?.toString(),
      status: json['status'] as String?,
      batch: json['batch'] is Map<String, dynamic>
          ? json['batch'] as Map<String, dynamic>
          : null,
    );
  }
}

class MyRequest {
  final String id;
  final String requestType;
  final String? fromBatchId;
  final String? toBatchId;
  final String? reason;
  final String status;
  final String? adminNote;
  final DateTime? resolvedAt;
  final DateTime? requestedAt;
  final Map<String, dynamic>? fromBatch;
  final Map<String, dynamic>? toBatch;

  MyRequest({
    required this.id,
    required this.requestType,
    this.fromBatchId,
    this.toBatchId,
    this.reason,
    required this.status,
    this.adminNote,
    this.resolvedAt,
    this.requestedAt,
    this.fromBatch,
    this.toBatch,
  });

  factory MyRequest.fromJson(Map<String, dynamic> json) {
    return MyRequest(
      id: json['id'].toString(),
      requestType: json['requestType'] as String? ?? 'hold',
      fromBatchId: json['fromBatchId']?.toString(),
      toBatchId: json['toBatchId']?.toString(),
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'pending',
      adminNote: json['adminNote'] as String?,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())
          : null,
      requestedAt: json['requestedAt'] != null
          ? DateTime.tryParse(json['requestedAt'].toString())
          : null,
      fromBatch: json['fromBatch'] is Map<String, dynamic>
          ? json['fromBatch'] as Map<String, dynamic>
          : null,
      toBatch: json['toBatch'] is Map<String, dynamic>
          ? json['toBatch'] as Map<String, dynamic>
          : null,
    );
  }
}
