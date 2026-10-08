import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'features/updates/update_checker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: EmteesApp()));
}

class EmteesApp extends ConsumerWidget {
  const EmteesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Emtees',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) {
        // Bottom-only SafeArea at the root: on edge-to-edge Android (and
        // devices with 3-button nav bars) content otherwise renders under
        // the system navigation bar since third-party widgets like the
        // notch bottom bar don't reserve that space themselves. Top is left
        // alone since individual screens' AppBars already handle that.
        return Stack(
          children: [
            if (child != null) SafeArea(top: false, child: child),
            const _RootOverlays(),
          ],
        );
      },
    );
  }
}

/// Hosts zero-size widgets that need to live above the router/navigator,
/// such as the OTA update checker.
class _RootOverlays extends StatelessWidget {
  const _RootOverlays();

  @override
  Widget build(BuildContext context) {
    return const UpdateChecker();
  }
}
