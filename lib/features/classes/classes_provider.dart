import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../models/class_item.dart';
import '../../models/one_to_one_session.dart';
import '../auth/auth_provider.dart';
import 'classes_repository.dart';

final classesRepositoryProvider = Provider<ClassesRepository>((ref) {
  return ClassesRepository(ref.watch(apiClientProvider));
});

/// Combined view of a group class or a 1:1 session for the unified list.
class ScheduleEntry {
  final ClassItem? classItem;
  final OneToOneSession? session;
  final bool _viewerIsTeacher;

  ScheduleEntry.fromClass(ClassItem c, {this._viewerIsTeacher = false})
      : classItem = c,
        session = null;
  ScheduleEntry.fromSession(OneToOneSession s, {this._viewerIsTeacher = false})
      : classItem = null,
        session = s;

  bool get isOneToOne => session != null;
  String get id => classItem?.id ?? session!.id;
  String get title => classItem?.title ?? session!.title;
  String get status => classItem?.status ?? session!.status;
  DateTime? get scheduledAt => classItem?.scheduledAt ?? session!.scheduledAt;
  int get _durationMinutes =>
      (classItem?.duration ?? session?.sessionLength ?? 30).clamp(1, 1000);

  DateTime? get _endTime {
    final start = scheduledAt;
    if (start == null) return null;
    return start.add(Duration(minutes: _durationMinutes));
  }

  /// Mirrors the web dashboard's live/starting-soon/upcoming logic exactly
  /// (Dashboard.tsx's `statusLabel`/`isPast` computation): a scheduled item
  /// is "live now" once the current time falls inside its
  /// [start, start+duration] window (even before the backend status flips
  /// to "live"/"ongoing"), "starting soon" inside the 30-minutes-before
  /// window, "upcoming" further out, and — importantly — once its end time
  /// has passed with the backend still saying "scheduled" (never started),
  /// it's treated as past rather than staying stuck in the upcoming list
  /// forever. Non-scheduled statuses (completed/cancelled/etc) pass through
  /// unchanged.
  String get displayStatus {
    if (status == 'live') return 'live_now';
    if (status != 'scheduled') return status;

    final start = scheduledAt;
    final end = _endTime;
    if (start == null || end == null) return 'upcoming';
    final now = DateTime.now();

    if (!now.isBefore(start) && !now.isAfter(end)) return 'live_now';
    if (now.isAfter(end)) return 'past';
    final diff = start.difference(now);
    if (diff <= const Duration(minutes: 30)) return 'starting_soon';
    return 'upcoming';
  }

  bool get isLive => displayStatus == 'live_now';
  bool get isScheduled =>
      displayStatus == 'starting_soon' || displayStatus == 'upcoming';
  bool get isPast =>
      status == 'completed' || status == 'cancelled' || displayStatus == 'past';

  /// For a 1:1 session this is always the *other* party relative to the
  /// viewer (student's name for a teacher, teacher's name for a student) —
  /// previously this always preferred `teacher`, so a teacher looking at
  /// their own session card saw their own name instead of the student's.
  String get subtitle {
    if (classItem != null) {
      return classItem!.batch?.name ?? classItem!.teacher?.name ?? '';
    }
    final other = _viewerIsTeacher ? session!.student : session!.teacher;
    return other?.name ??
        session!.teacher?.name ??
        session!.student?.name ??
        '';
  }
}

class ScheduleState {
  final bool loading;
  final String? error;
  final List<ScheduleEntry> entries;

  const ScheduleState({
    this.loading = false,
    this.error,
    this.entries = const [],
  });

  ScheduleState copyWith({
    bool? loading,
    String? error,
    List<ScheduleEntry>? entries,
  }) {
    return ScheduleState(
      loading: loading ?? this.loading,
      error: error,
      entries: entries ?? this.entries,
    );
  }

  List<ScheduleEntry> get live =>
      entries.where((e) => e.isLive).toList()
        ..sort((a, b) => (a.scheduledAt ?? DateTime.now())
            .compareTo(b.scheduledAt ?? DateTime.now()));

  List<ScheduleEntry> get upcoming => entries.where((e) => e.isScheduled).toList()
    ..sort((a, b) => (a.scheduledAt ?? DateTime.now())
        .compareTo(b.scheduledAt ?? DateTime.now()));

  List<ScheduleEntry> get past => entries.where((e) => e.isPast).toList()
    ..sort((a, b) => (b.scheduledAt ?? DateTime.now())
        .compareTo(a.scheduledAt ?? DateTime.now()));
}

final scheduleProvider =
    NotifierProvider<ScheduleNotifier, ScheduleState>(ScheduleNotifier.new);

class ScheduleNotifier extends Notifier<ScheduleState> {
  @override
  ScheduleState build() {
    Future.microtask(refresh);
    return const ScheduleState(loading: true);
  }

  Future<void> refresh() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = ref.read(classesRepositoryProvider);
      final classesFuture = repo.fetchClasses();
      final oneToOneFuture = user.isTeacher
          ? repo.fetchOneToOne(teacherId: user.id)
          : repo.fetchOneToOne(studentId: user.id);

      final results = await Future.wait([classesFuture, oneToOneFuture]);
      final classes = results[0] as List<ClassItem>;
      final sessions = results[1] as List<OneToOneSession>;

      // GET /classes already merges 1:1 sessions into its results
      // (classType: "one_to_one") alongside group classes, and GET
      // /one-to-one returns the same sessions again with the fuller
      // OneToOneSession shape. Without filtering these out here, every 1:1
      // session showed up twice — once via each endpoint, with different
      // icons — doubling the upcoming/live counts.
      final groupClasses = classes.where((c) => c.classType != 'one_to_one');

      final entries = <ScheduleEntry>[
        ...groupClasses.map((c) => ScheduleEntry.fromClass(c, viewerIsTeacher: user.isTeacher)),
        ...sessions.map((s) => ScheduleEntry.fromSession(s, viewerIsTeacher: user.isTeacher)),
      ];
      state = ScheduleState(entries: entries);
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Could not load your classes. Pull to refresh to try again.',
      );
    }
  }
}
