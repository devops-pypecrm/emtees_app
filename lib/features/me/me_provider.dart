import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../models/my_data.dart';
import '../../models/phase3.dart';
import '../auth/auth_provider.dart';
import 'me_repository.dart';

final meRepositoryProvider = Provider<MeRepository>((ref) {
  return MeRepository(ref.watch(apiClientProvider));
});

class AsyncListState<T> {
  final bool loading;
  final String? error;
  final List<T> items;

  const AsyncListState({this.loading = false, this.error, this.items = const []});

  AsyncListState<T> copyWith({bool? loading, String? error, List<T>? items}) {
    return AsyncListState<T>(
      loading: loading ?? this.loading,
      error: error,
      items: items ?? this.items,
    );
  }
}

final myBatchesProvider =
    NotifierProvider<MyBatchesNotifier, AsyncListState<MyBatch>>(
  MyBatchesNotifier.new,
);

class MyBatchesNotifier extends Notifier<AsyncListState<MyBatch>> {
  @override
  AsyncListState<MyBatch> build() {
    Future.microtask(refresh);
    return const AsyncListState(loading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await ref.read(meRepositoryProvider).fetchMyBatches();
      state = AsyncListState(items: items);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load your batches. Pull to refresh to try again.',
      );
    }
  }
}

final myRequestsProvider =
    NotifierProvider<MyRequestsNotifier, AsyncListState<MyRequest>>(
  MyRequestsNotifier.new,
);

class MyRequestsNotifier extends Notifier<AsyncListState<MyRequest>> {
  @override
  AsyncListState<MyRequest> build() {
    Future.microtask(refresh);
    return const AsyncListState(loading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await ref.read(meRepositoryProvider).fetchMyRequests();
      state = AsyncListState(items: items);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load your requests. Pull to refresh to try again.',
      );
    }
  }

  Future<bool> createRequest({
    required String requestType,
    String? fromBatchId,
    String? toBatchId,
    String? reason,
  }) async {
    try {
      await ref.read(meRepositoryProvider).createRequest(
            requestType: requestType,
            fromBatchId: fromBatchId,
            toBatchId: toBatchId,
            reason: reason,
          );
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelRequest(String id) async {
    try {
      await ref.read(meRepositoryProvider).cancelRequest(id);
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final myFeedbackProvider =
    NotifierProvider<MyFeedbackNotifier, AsyncListState<FeedbackItem>>(
  MyFeedbackNotifier.new,
);

class MyFeedbackNotifier extends Notifier<AsyncListState<FeedbackItem>> {
  @override
  AsyncListState<FeedbackItem> build() {
    Future.microtask(refresh);
    return const AsyncListState(loading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await ref.read(meRepositoryProvider).fetchMyFeedback();
      state = AsyncListState(items: items);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load your feedback. Pull to refresh to try again.',
      );
    }
  }

  /// Throws [ApiException] on failure so the UI can surface the server's
  /// message (e.g. duplicate feedback, edit window expired).
  Future<void> submitFeedback({
    required String teacherId,
    required String batchId,
    String? classId,
    required int rating,
    String? comment,
  }) async {
    await ref.read(meRepositoryProvider).createFeedback(
          teacherId: teacherId,
          batchId: batchId,
          classId: classId,
          rating: rating,
          comment: comment,
        );
    await refresh();
  }

  Future<void> editFeedback(String id, {int? rating, String? comment}) async {
    await ref
        .read(meRepositoryProvider)
        .updateFeedback(id, rating: rating, comment: comment);
    await refresh();
  }
}

final myPaymentsProvider =
    NotifierProvider<MyPaymentsNotifier, AsyncListState<Map<String, dynamic>>>(
  MyPaymentsNotifier.new,
);

class MyPaymentsNotifier
    extends Notifier<AsyncListState<Map<String, dynamic>>> {
  @override
  AsyncListState<Map<String, dynamic>> build() {
    Future.microtask(refresh);
    return const AsyncListState(loading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await ref.read(meRepositoryProvider).fetchMyPayments();
      state = AsyncListState(items: items);
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load your payments. Pull to refresh to try again.',
      );
    }
  }
}

class ProfileEditState {
  final bool saving;
  final String? error;
  const ProfileEditState({this.saving = false, this.error});
}

final profileEditProvider =
    NotifierProvider<ProfileEditNotifier, ProfileEditState>(
  ProfileEditNotifier.new,
);

class ProfileEditNotifier extends Notifier<ProfileEditState> {
  @override
  ProfileEditState build() => const ProfileEditState();

  Future<bool> save({
    required String name,
    String? username,
    String? phoneNumber,
  }) async {
    state = const ProfileEditState(saving: true);
    try {
      await ref.read(meRepositoryProvider).updateProfile(
            name: name,
            username: username,
            phoneNumber: phoneNumber,
            phone: phoneNumber,
          );
      state = const ProfileEditState();
      // Refresh cached user so Profile screen reflects the change.
      await ref.read(authProvider.notifier).refreshUser();
      return true;
    } on ApiException catch (e) {
      state = ProfileEditState(error: e.message);
      return false;
    } catch (_) {
      state = const ProfileEditState(error: 'Could not save your profile.');
      return false;
    }
  }
}

class PasswordChangeState {
  final bool saving;
  final String? error;
  const PasswordChangeState({this.saving = false, this.error});
}

final passwordChangeProvider =
    NotifierProvider<PasswordChangeNotifier, PasswordChangeState>(
  PasswordChangeNotifier.new,
);

class PasswordChangeNotifier extends Notifier<PasswordChangeState> {
  @override
  PasswordChangeState build() => const PasswordChangeState();

  Future<bool> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const PasswordChangeState(saving: true);
    try {
      await ref.read(meRepositoryProvider).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      state = const PasswordChangeState();
      return true;
    } on ApiException catch (e) {
      state = PasswordChangeState(error: e.message);
      return false;
    } catch (_) {
      state = const PasswordChangeState(error: 'Could not change your password.');
      return false;
    }
  }
}
