import '../../core/api_client.dart';

/// Role-scoped class/salary reports. The backend enforces scope: teachers only
/// ever receive their own numbers and students only their own report.
class ReportsRepository {
  ReportsRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> daily(String date) async {
    final data = await _api.getList('/reports/daily', query: {'date': date});
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> range(String startDate, String endDate) async {
    final data = await _api.getList('/reports/range',
        query: {'startDate': startDate, 'endDate': endDate});
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> mySalary(String month) {
    return _api.getJson('/reports/my-salary', query: {'month': month});
  }

  Future<Map<String, dynamic>> studentReport(String studentId) {
    return _api.getJson('/reports/student/$studentId');
  }
}
