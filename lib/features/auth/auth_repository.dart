import 'dart:convert';

import '../../core/api_client.dart';
import '../../core/secure_storage.dart';
import '../../models/user.dart';

class LoginResult {
  final String token;
  final AppUser user;
  LoginResult({required this.token, required this.user});
}

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final SecureStorageService _storage;

  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final data = await _api.postJson('/auth/login', body: {
      'username': username,
      'password': password,
    });
    final token = data['token'] as String;
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.writeToken(token);
    await _storage.writeUser(jsonEncode(user.toJson()));
    return LoginResult(token: token, user: user);
  }

  /// Validates the stored token and refreshes the cached profile.
  /// Returns null if there is no valid session.
  Future<AppUser?> fetchMe() async {
    try {
      final data = await _api.getJson('/auth/me');
      if (data.isEmpty) return null;
      final user = AppUser.fromJson(data);
      await _storage.writeUser(jsonEncode(user.toJson()));
      return user;
    } on ApiException {
      return null;
    }
  }

  Future<AppUser?> readCachedUser() async {
    final raw = await _storage.readUser();
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<String?> readToken() => _storage.readToken();

  Future<void> logout() => _storage.clear();
}
