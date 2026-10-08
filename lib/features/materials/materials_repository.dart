import '../../core/api_client.dart';
import '../../models/phase3.dart';

class MaterialsRepository {
  MaterialsRepository(this._api);

  final ApiClient _api;

  Future<List<LearningMaterial>> fetchMaterials(String batchId) async {
    final data = await _api.getList('/materials', query: {'batchId': batchId});
    return data
        .whereType<Map>()
        .map((e) => LearningMaterial.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<LearningMaterial> createMaterial({
    required String batchId,
    required String title,
    String? description,
    String type = 'text',
    String? contentUrl,
    DateTime? scheduledDate,
  }) async {
    final data = await _api.postJson('/materials', body: {
      'batchId': batchId,
      'title': title,
      if (description != null && description.isNotEmpty) 'description': description,
      'type': type,
      if (contentUrl != null && contentUrl.isNotEmpty) 'contentUrl': contentUrl,
      if (scheduledDate != null) 'scheduledDate': scheduledDate.toIso8601String(),
    });
    return LearningMaterial.fromJson(data);
  }
}
