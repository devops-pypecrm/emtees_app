import '../../core/api_client.dart';
import '../../models/phase3.dart';

class PerformanceRepository {
  PerformanceRepository(this._api);

  final ApiClient _api;

  Future<List<PerformanceReport>> fetchReports() async {
    final data = await _api.getList('/performance');
    return data
        .whereType<Map>()
        .map((e) => PerformanceReport.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchHistory(String id) async {
    final data = await _api.getDynamic('/performance/$id/history');
    if (data is List) {
      return data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    }
    return const [];
  }
}
