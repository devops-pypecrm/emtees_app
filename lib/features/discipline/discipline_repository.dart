import '../../core/api_client.dart';
import '../../models/phase3.dart';

class DisciplineRepository {
  DisciplineRepository(this._api);

  final ApiClient _api;

  Future<List<DisciplineRecord>> fetchRecords() async {
    final data = await _api.getList('/discipline');
    return data
        .whereType<Map>()
        .map((e) => DisciplineRecord.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, dynamic>?> fetchStats() async {
    try {
      final data = await _api.getDynamic('/discipline/stats');
      if (data is Map) return data.cast<String, dynamic>();
    } catch (_) {}
    return null;
  }

  Future<DisciplineRecord> createRecord({
    required String userId,
    required String batch,
    required String level,
    required String reason,
    required String description,
  }) async {
    final data = await _api.postJson('/discipline', body: {
      'userId': userId,
      'batch': batch,
      'level': level,
      'reason': reason,
      'description': description,
    });
    return DisciplineRecord.fromJson(data);
  }
}
