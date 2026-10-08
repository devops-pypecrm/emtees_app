import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/release_manifest.dart';
import 'app_release_repository.dart';

final appReleaseRepositoryProvider = Provider<AppReleaseRepository>((ref) {
  return AppReleaseRepository();
});

/// The real installed package info (version name/build number).
final currentPackageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// Latest published release manifest for this platform, or null if there is
/// none / it can't be reached.
final latestReleaseProvider = FutureProvider<ReleaseManifest?>((ref) async {
  final repo = ref.watch(appReleaseRepositoryProvider);
  return repo.fetchLatest();
});

/// Non-null only when the latest published release is newer (by versionCode)
/// than what's installed.
final availableUpdateProvider = Provider<ReleaseManifest?>((ref) {
  final latest = ref.watch(latestReleaseProvider).valueOrNull;
  final currentInfo = ref.watch(currentPackageInfoProvider).valueOrNull;
  if (latest == null || currentInfo == null) return null;
  final currentBuild = int.tryParse(currentInfo.buildNumber) ?? 0;
  if (latest.versionCode > currentBuild) return latest;
  return null;
});

const _dismissedVersionKey = 'emtees_dismissed_update_version_code';

/// The versionCode of the update the user chose "Later" for this session,
/// persisted across app restarts until a newer release comes out.
final dismissedUpdateVersionProvider =
    NotifierProvider<DismissedUpdateVersionNotifier, int?>(
  DismissedUpdateVersionNotifier.new,
);

class DismissedUpdateVersionNotifier extends Notifier<int?> {
  @override
  int? build() {
    Future.microtask(_restore);
    return null;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_dismissedVersionKey);
  }

  Future<void> dismiss(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dismissedVersionKey, versionCode);
    state = versionCode;
  }
}

/// True only if an update is available and its versionCode hasn't already
/// been dismissed this "session" (persisted, so effectively per-version).
final pendingUpdatePromptProvider = Provider<bool>((ref) {
  final available = ref.watch(availableUpdateProvider);
  final dismissed = ref.watch(dismissedUpdateVersionProvider);
  if (available == null) return false;
  return available.versionCode != dismissed;
});
