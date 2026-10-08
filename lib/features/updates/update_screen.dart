import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../models/release_manifest.dart';
import 'update_provider.dart';

enum _Stage { info, downloading, readyToInstall, error }

/// Full-screen, animated update flow — replaces the old blocking dialog.
/// Shows live download progress, offers a direct-from-web fallback on
/// failure, and keeps a persistent "install" option after downloading so a
/// dismissed/cancelled system install prompt doesn't force a re-download.
class UpdateScreen extends ConsumerStatefulWidget {
  const UpdateScreen({super.key, required this.manifest});

  final ReleaseManifest manifest;

  @override
  ConsumerState<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends ConsumerState<UpdateScreen>
    with TickerProviderStateMixin {
  _Stage _stage = _Stage.info;
  double _progress = 0;
  String? _errorMessage;
  String? _downloadedApkPath;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    _checkForExistingDownload();
  }

  /// If a previous attempt already downloaded the APK (e.g. the user
  /// dismissed the system install prompt and came back), skip straight to
  /// the install step instead of downloading all over again.
  Future<void> _checkForExistingDownload() async {
    final path = await _expectedApkPath();
    if (await File(path).exists()) {
      if (!mounted) return;
      setState(() {
        _downloadedApkPath = path;
        _stage = _Stage.readyToInstall;
      });
      _bounce
        ..reset()
        ..forward();
    }
  }

  Future<String> _expectedApkPath() async {
    final dir = await getTemporaryDirectory();
    final fileName = widget.manifest.apkFileName.isNotEmpty
        ? widget.manifest.apkFileName
        : 'emtees-update.apk';
    return '${dir.path}/$fileName';
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    _spin.dispose();
    _bounce.dispose();
    super.dispose();
  }

  bool get _canLeave => _stage != _Stage.downloading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: _canLeave,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (_canLeave)
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              Expanded(
                child: Center(
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                        parent: _entrance, curve: Curves.easeOut),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.06),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: _entrance, curve: Curves.easeOutCubic)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildIcon(scheme),
                            const SizedBox(height: 36),
                            _buildBody(scheme),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(ColorScheme scheme) {
    switch (_stage) {
      case _Stage.info:
        return ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0)
              .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
          child: _iconCircle(scheme, scheme.primaryContainer,
              Icon(Icons.system_update_rounded, size: 56, color: scheme.onPrimaryContainer)),
        );
      case _Stage.downloading:
        return SizedBox(
          width: 148,
          height: 148,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 148,
                height: 148,
                child: CircularProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  strokeWidth: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(scheme.primary),
                ),
              ),
              if (_progress > 0)
                Text(
                  '${(_progress * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary),
                )
              else
                RotationTransition(
                  turns: _spin,
                  child: Icon(Icons.downloading_rounded, size: 40, color: scheme.primary),
                ),
            ],
          ),
        );
      case _Stage.readyToInstall:
        return ScaleTransition(
          scale: CurvedAnimation(parent: _bounce, curve: Curves.elasticOut),
          child: _iconCircle(scheme, scheme.tertiaryContainer,
              Icon(Icons.check_rounded, size: 56, color: scheme.onTertiaryContainer)),
        );
      case _Stage.error:
        return AnimatedBuilder(
          animation: _bounce,
          builder: (context, child) {
            final dx = (1 - _bounce.value) *
                8 *
                (1 - _bounce.value) *
                (_bounce.value < 0.5 ? 1 : -1);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: _iconCircle(scheme, scheme.errorContainer,
              Icon(Icons.error_outline_rounded, size: 56, color: scheme.onErrorContainer)),
        );
    }
  }

  Widget _iconCircle(ColorScheme scheme, Color bg, Widget child) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(child: child),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    switch (_stage) {
      case _Stage.info:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Update available', textAlign: TextAlign.center, style: textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('Version ${widget.manifest.versionName}',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            if ((widget.manifest.releaseNotes?.trim().isNotEmpty ?? false))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.manifest.releaseNotes!.trim(),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 32),
            if (Platform.isIOS)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Sideloaded updates aren\'t supported on iOS.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _openWebDownload,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Open download page'),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _startDownload,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('Update now'),
                ),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                ref
                    .read(dismissedUpdateVersionProvider.notifier)
                    .dismiss(widget.manifest.versionCode);
                Navigator.of(context).maybePop();
              },
              child: const Text('Later'),
            ),
          ],
        );
      case _Stage.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Downloading update…', textAlign: TextAlign.center, style: textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              _progress > 0 ? 'Hang tight, almost there' : 'Starting download…',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        );
      case _Stage.readyToInstall:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Ready to install', textAlign: TextAlign.center, style: textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Version ${widget.manifest.versionName} is downloaded. Tap below to install it.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openInstaller,
                icon: const Icon(Icons.install_mobile_rounded),
                label: const Text('Install now'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Later'),
            ),
          ],
        );
      case _Stage.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Download failed', textAlign: TextAlign.center, style: textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openWebDownload,
                icon: const Icon(Icons.open_in_browser),
                label: const Text('Download from website instead'),
              ),
            ),
          ],
        );
    }
  }

  Future<void> _openWebDownload() async {
    final uri = Uri.parse('${AppConfig.socketBaseUrl}/app');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Launches the OS installer for the already-downloaded APK. Doesn't pop
  /// the screen — if the user dismisses/cancels the system install prompt by
  /// mistake, they land back here with the same "Install now" button rather
  /// than having to re-download.
  Future<void> _openInstaller() async {
    final path = _downloadedApkPath;
    if (path == null) return;
    await OpenFilex.open(path);
  }

  Future<void> _startDownload() async {
    setState(() {
      _stage = _Stage.downloading;
      _progress = 0;
      _errorMessage = null;
    });
    try {
      final repo = ref.read(appReleaseRepositoryProvider);
      final path = await _expectedApkPath();

      await repo.downloadApk(
        savePath: path,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p < 0 ? 0 : p);
        },
      );

      if (!mounted) return;
      setState(() {
        _stage = _Stage.readyToInstall;
        _downloadedApkPath = path;
      });
      _bounce
        ..reset()
        ..forward();
      // Convenience: try opening the installer immediately. The screen
      // stays in readyToInstall regardless, so a dismissed/cancelled prompt
      // just leaves the persistent "Install now" button available.
      await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _errorMessage = _shortError(e);
      });
      _bounce
        ..reset()
        ..forward();
    }
  }

  String _shortError(Object e) {
    if (kDebugMode) return e.toString();
    return 'Please check your connection and try again.';
  }
}
