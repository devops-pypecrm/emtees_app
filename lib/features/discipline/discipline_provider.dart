import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/phase3.dart';
import '../me/me_provider.dart';
import 'discipline_repository.dart';

final disciplineRepositoryProvider = Provider<DisciplineRepository>((ref) {
  return DisciplineRepository(ref.watch(apiClientProvider));
});

final disciplineProvider =
    NotifierProvider<DisciplineNotifier, AsyncListState<DisciplineRecord>>(
  DisciplineNotifier.new,
);

class DisciplineNotifier extends Notifier<AsyncListState<DisciplineRecord>> {
  @override
  AsyncListState<DisciplineRecord> build() {
    Future.microtask(refresh);
    return const AsyncListState(loading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await ref.read(disciplineRepositoryProvider).fetchRecords();
      state = AsyncListState(items: items);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load discipline records. Pull to refresh to try again.',
      );
    }
  }

  Future<bool> fileReport({
    required String userId,
    required String batch,
    required String level,
    required String reason,
    required String description,
  }) async {
    try {
      await ref.read(disciplineRepositoryProvider).createRecord(
            userId: userId,
            batch: batch,
            level: level,
            reason: reason,
            description: description,
          );
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }
}
