import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router.dart';
import 'update_provider.dart';
import 'update_screen.dart';

/// Zero-size widget mounted once at the app root (above the router). Watches
/// [pendingUpdatePromptProvider] and pushes the full-screen [UpdateScreen] at
/// most once per dismissed-version, without affecting layout.
class UpdateChecker extends ConsumerWidget {
  const UpdateChecker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(pendingUpdatePromptProvider, (previous, show) {
      if (show == true && previous != true) {
        final manifest = ref.read(availableUpdateProvider);
        if (manifest != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final rootContext = rootNavigatorKey.currentContext;
            if (rootContext != null) {
              rootContext.push('/update', extra: manifest);
            }
          });
        }
      }
    });
    return const SizedBox.shrink();
  }
}
