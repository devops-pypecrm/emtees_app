import 'package:dio/dio.dart';

import '../../core/config.dart';
import '../../models/release_manifest.dart';

/// Wraps GET /app-releases/latest and the APK download. Never throws for
/// "no release published" (404) or network errors — returns null instead so
/// the update-check UI can simply do nothing when there's no update info.
class AppReleaseRepository {
  AppReleaseRepository() : _dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));

  final Dio _dio;

  Future<ReleaseManifest?> fetchLatest() async {
    try {
      final response = await _dio.get(
        '/app-releases/latest',
        queryParameters: {'platform': 'mobile'},
      );
      if (response.data is! Map<String, dynamic>) return null;
      return ReleaseManifest.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads the APK to [savePath], reporting progress via [onProgress]
  /// (0.0-1.0, or -1 if the total size is unknown).
  Future<void> downloadApk({
    required String savePath,
    void Function(double progress)? onProgress,
  }) async {
    await _dio.download(
      '/app-releases/download/mobile',
      savePath,
      onReceiveProgress: (received, total) {
        if (onProgress == null) return;
        if (total <= 0) {
          onProgress(-1);
        } else {
          onProgress(received / total);
        }
      },
    );
  }
}
