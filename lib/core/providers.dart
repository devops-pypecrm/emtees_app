import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'secure_storage.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage);
});
