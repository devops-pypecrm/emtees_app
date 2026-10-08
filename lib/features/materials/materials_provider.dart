import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/phase3.dart';
import '../me/me_provider.dart';
import 'materials_repository.dart';

final materialsRepositoryProvider = Provider<MaterialsRepository>((ref) {
  return MaterialsRepository(ref.watch(apiClientProvider));
});

final materialsProvider = NotifierProvider.family<MaterialsNotifier,
    AsyncListState<LearningMaterial>, String>(MaterialsNotifier.new);

class MaterialsNotifier
    extends FamilyNotifier<AsyncListState<LearningMaterial>, String> {
  @override
  AsyncListState<LearningMaterial> build(String batchId) {
    Future.microtask(refresh);
    return const AsyncListState(loading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items =
          await ref.read(materialsRepositoryProvider).fetchMaterials(arg);
      state = AsyncListState(items: items);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load materials. Pull to refresh to try again.',
      );
    }
  }

  Future<bool> create({
    required String title,
    String? description,
    String type = 'text',
    String? contentUrl,
  }) async {
    try {
      await ref.read(materialsRepositoryProvider).createMaterial(
            batchId: arg,
            title: title,
            description: description,
            type: type,
            contentUrl: contentUrl,
          );
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }
}
