import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/phase3.dart';
import '../me/me_provider.dart';
import 'performance_repository.dart';

final performanceRepositoryProvider = Provider<PerformanceRepository>((ref) {
  return PerformanceRepository(ref.watch(apiClientProvider));
});

final performanceProvider =
    NotifierProvider<PerformanceNotifier, AsyncListState<PerformanceReport>>(
  PerformanceNotifier.new,
);

class PerformanceNotifier
    extends Notifier<AsyncListState<PerformanceReport>> {
  @override
  AsyncListState<PerformanceReport> build() {
    Future.microtask(refresh);
    return const AsyncListState(loading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await ref.read(performanceRepositoryProvider).fetchReports();
      state = AsyncListState(items: items);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load performance reports. Pull to refresh to try again.',
      );
    }
  }
}
