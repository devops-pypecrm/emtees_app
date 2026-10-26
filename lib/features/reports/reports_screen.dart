import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../auth/auth_provider.dart';
import '../realtime/socket_service.dart';
import 'report_ranges.dart';
import 'reports_repository.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(apiClientProvider));
});

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String _ym(DateTime d) => DateFormat('yyyy-MM').format(d);
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _inr(dynamic v) =>
    '₹${NumberFormat.decimalPattern('en_IN').format(v is num ? v : num.tryParse('$v') ?? 0)}';

/// Reports entry point; shows the view that matches the signed-in role.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (user.isTeacher) return const _TeacherReports();
    if (user.isStudent) return _StudentReport(studentId: user.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Admin and Academic Head reports are available on the web portal.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── shared widgets ─────────────────────────

class _AsyncBody<T> extends StatelessWidget {
  const _AsyncBody({required this.future, required this.builder, required this.onRetry});

  final Future<T>? future;
  final Widget Function(BuildContext, T) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        // Refreshing keeps the previous data on screen (no spinner flicker).
        if (!snap.hasData && snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 12),
                Text('${snap.error}', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => onRetry(),
          child: builder(context, snap.data as T),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700, color: color ?? scheme.primary)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ───────────────────────── teacher ─────────────────────────

class _TeacherReports extends StatelessWidget {
  const _TeacherReports();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Reports'),
          bottom: const TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Today'),
            Tab(text: 'Sessions'),
            Tab(text: 'Date range'),
            Tab(text: 'Salary'),
          ]),
        ),
        body: const TabBarView(children: [
          _OverviewTab(),
          _TodayTab(),
          _SessionsTab(),
          _RangeTab(),
          _SalaryTab(),
        ]),
      ),
    );
  }
}

/// Keeps a report tab fresh: reloads every 30 s and whenever the server announces a class change
/// (e.g. a student was just counted), so nobody has to pull to refresh.
mixin _LiveRefresh<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  Timer? _liveTimer;

  void reloadReport();

  void startLiveRefresh() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) reloadReport();
    });
  }

  void listenForClassChanges() {
    ref.listen(realtimeEventsProvider, (previous, next) {
      final event = next.valueOrNull;
      if (event != null && {'class:updated', 'class:started', 'class:ended'}.contains(event.type) && mounted) {
        reloadReport();
      }
    });
  }

  void stopLiveRefresh() => _liveTimer?.cancel();
}

class _TodayTab extends ConsumerStatefulWidget {
  const _TodayTab();

  @override
  ConsumerState<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<_TodayTab> with _LiveRefresh<_TodayTab> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  void reloadReport() => _load();

  void _load() {
    setState(() {
      _future = ref.read(reportsRepositoryProvider).daily(_ymd(DateTime.now()));
    });
  }

  @override
  Widget build(BuildContext context) {
    listenForClassChanges();
    return _AsyncBody<List<Map<String, dynamic>>>(
      future: _future,
      onRetry: _load,
      builder: (context, rows) {
        final d = rows.isNotEmpty ? rows.first : <String, dynamic>{};
        final pending = _int(d['pending']) + _int(d['ongoing']);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _Stat('Assigned', '${_int(d['assigned'])}'),
              _Stat('Completed', '${_int(d['completed'])}', color: Colors.green),
              _Stat('Pending', '$pending', color: Colors.orange),
              _Stat('Invalid (under 20 min)', '${_int(d['invalid'])}', color: Colors.red),
            ]),
            const SizedBox(height: 12),
            const Text('A class counts once you and the student have both stayed at least 20 minutes. '
                'A drop of up to 5 minutes is bridged if you rejoin.'),
          ],
        );
      },
    );
  }
}

// ───────────────────────── overview (date presets → totals → class lists) ─────────────────────────

String _presetLabel(ReportPreset p) => switch (p) {
      ReportPreset.today => 'Today',
      ReportPreset.yesterday => 'Yesterday',
      ReportPreset.lastWeek => 'Last week',
      ReportPreset.lastMonth => 'Last month',
      ReportPreset.custom => 'Custom',
    };

String _rowStatusLabel(Map<String, dynamic> r, DateTime now) {
  switch (bucketOfClass(r, now)) {
    case ClassBucket.completed:
      return 'Counted';
    case ClassBucket.pending:
      return '${r['status']}' == 'ongoing' ? 'Live' : 'Upcoming';
    case ClassBucket.notTaken:
      return '${r['status']}' == 'completed' ? 'Under minimum' : 'Not taken';
    case ClassBucket.assigned:
      return '';
  }
}

Color _bucketColor(ClassBucket b) => switch (b) {
      ClassBucket.assigned => Colors.blueGrey,
      ClassBucket.completed => Colors.green,
      ClassBucket.pending => Colors.orange,
      ClassBucket.notTaken => Colors.red,
    };

String _bucketTitle(ClassBucket b) => switch (b) {
      ClassBucket.assigned => 'Assigned classes',
      ClassBucket.completed => 'Completed classes',
      ClassBucket.pending => 'Pending classes',
      ClassBucket.notTaken => 'Not taken classes',
    };

class _OverviewTab extends ConsumerStatefulWidget {
  const _OverviewTab();

  @override
  ConsumerState<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends ConsumerState<_OverviewTab> with _LiveRefresh<_OverviewTab> {
  ReportPreset _preset = ReportPreset.today;
  late DateTimeRange _range;
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _range = rangeForPreset(ReportPreset.today, DateTime.now());
    _load();
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  void reloadReport() => _load();

  void _load() {
    // Presets are recomputed on every load so "Today" rolls over at midnight.
    if (_preset != ReportPreset.custom) _range = rangeForPreset(_preset, DateTime.now());
    setState(() {
      _future = ref.read(reportsRepositoryProvider).sessions(_ymd(_range.start), _ymd(_range.end));
    });
  }

  Future<void> _select(ReportPreset p) async {
    if (p == ReportPreset.custom) {
      final now = DateTime.now();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2023),
        lastDate: now.add(const Duration(days: 365)),
        initialDateRange: _range,
      );
      if (picked == null) return;
      _range = picked;
    }
    _preset = p;
    _load();
  }

  String get _rangeText {
    final f = DateFormat('EEE, MMM d');
    final f2 = DateFormat('MMM d, y');
    if (_range.start == _range.end) return f2.format(_range.start);
    return '${f.format(_range.start)} – ${f2.format(_range.end)}';
  }

  void _open(ClassBucket b, List<Map<String, dynamic>> rows) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ClassListPage(bucket: b, rows: rows, rangeText: _rangeText),
    ));
  }

  @override
  Widget build(BuildContext context) {
    listenForClassChanges();
    return Column(
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final p in ReportPreset.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: p == ReportPreset.custom ? const Icon(Icons.date_range, size: 18) : null,
                    label: Text(_presetLabel(p)),
                    selected: _preset == p,
                    onSelected: (_) => _select(p),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_rangeText, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        Expanded(
          child: _AsyncBody<List<Map<String, dynamic>>>(
            future: _future,
            onRetry: _load,
            builder: (context, rows) {
              final now = DateTime.now();
              final groups = <ClassBucket, List<Map<String, dynamic>>>{
                ClassBucket.assigned: List.of(rows),
                ClassBucket.completed: [],
                ClassBucket.pending: [],
                ClassBucket.notTaken: [],
              };
              for (final r in rows) {
                groups[bucketOfClass(r, now)]!.add(r);
              }
              final width = (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2;
              Widget card(ClassBucket b, String label) => SizedBox(
                    width: width,
                    child: _TapStat(
                      label: label,
                      value: groups[b]!.length,
                      color: _bucketColor(b),
                      onTap: () => _open(b, groups[b]!),
                    ),
                  );
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    card(ClassBucket.assigned, 'Assigned'),
                    card(ClassBucket.completed, 'Completed'),
                    card(ClassBucket.pending, 'Pending'),
                    card(ClassBucket.notTaken, 'Not taken'),
                  ]),
                  const SizedBox(height: 16),
                  Text(
                    'Tap a box to see those classes, then tap a class to open its report.\n'
                    'Completed = counted (you and the student both stayed the minimum time). '
                    'Pending = live now or still to come. '
                    'Not taken = the time passed without a class, or it ended under the minimum.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TapStat extends StatelessWidget {
  const _TapStat({required this.label, required this.value, required this.color, required this.onTap});

  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700, color: color)),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
                Icon(Icons.chevron_right, size: 20, color: color),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// The classes behind one box. Tapping a class opens its class report.
class _ClassListPage extends StatelessWidget {
  const _ClassListPage({required this.bucket, required this.rows, required this.rangeText});

  final ClassBucket bucket;
  final List<Map<String, dynamic>> rows;
  final String rangeText;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final color = _bucketColor(bucket);
    final sorted = List<Map<String, dynamic>>.of(rows);
    DateTime at(Map<String, dynamic> r) =>
        DateTime.tryParse('${r['scheduledAt']}')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
    // Upcoming first for pending, newest first for everything else.
    sorted.sort((a, b) => bucket == ClassBucket.pending ? at(a).compareTo(at(b)) : at(b).compareTo(at(a)));

    return Scaffold(
      appBar: AppBar(
        title: Text(_bucketTitle(bucket)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${sorted.length} · $rangeText', style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
      ),
      body: sorted.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No classes here.')))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final r = sorted[i];
                final students = ((r['students'] as List?) ?? []).cast<Map<String, dynamic>>();
                final who = students.isEmpty
                    ? 'No students'
                    : students.length == 1
                        ? '${students.first['name']}'
                        : '${students.length} students';
                final when = DateFormat('EEE, MMM d · h:mm a').format(at(r));
                final label = _rowStatusLabel(r, now);
                final b = bucketOfClass(r, now);
                final stu = students.length == 1 ? ' · Student ${students.first['minutes'] ?? 0} min' : '';
                return Card(
                  child: ListTile(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => _SessionDetailSheet(
                        type: '${r['type']}',
                        id: '${r['id']}',
                        title: '${r['title'] ?? 'Class'}',
                      ),
                    ),
                    title: Text(who),
                    subtitle: Text('$when\n${r['sessionLength'] ?? '-'} min class · You ${r['teacherMinutes'] ?? 0} min$stu'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label,
                            style: TextStyle(
                                color: bucket == ClassBucket.assigned ? _bucketColor(b) : color,
                                fontWeight: FontWeight.w600)),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _SessionsTab extends ConsumerStatefulWidget {
  const _SessionsTab();

  @override
  ConsumerState<_SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends ConsumerState<_SessionsTab> with _LiveRefresh<_SessionsTab> {
  late DateTimeRange _range;
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    _load();
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  void reloadReport() => _load();

  void _load() {
    // keep "to" at the current moment so sessions started after the tab opened still appear
    final end = DateTime.now();
    if (end.isAfter(_range.end)) _range = DateTimeRange(start: _range.start, end: end);
    setState(() {
      _future = ref.read(reportsRepositoryProvider).sessions(_ymd(_range.start), _ymd(_range.end));
    });
  }

  Future<void> _pick() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) {
      _range = picked;
      _load();
    }
  }

  String _mins(dynamic v) {
    final n = v is num ? v : num.tryParse('$v') ?? 0;
    return n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(1);
  }

  void _openDetail(Map<String, dynamic> s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SessionDetailSheet(
        type: '${s['type']}',
        id: '${s['id']}',
        title: '${s['title'] ?? 'Session'}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    listenForClassChanges();
    final fmt = DateFormat('MMM d');
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.date_range),
          title: Text('${fmt.format(_range.start)} – ${fmt.format(_range.end)}'),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: _pick,
        ),
        Expanded(
          child: _AsyncBody<List<Map<String, dynamic>>>(
            future: _future,
            onRetry: _load,
            builder: (context, rows) {
              if (rows.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    Padding(padding: EdgeInsets.all(48), child: Center(child: Text('No sessions in this range.'))),
                  ],
                );
              }
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final s = rows[i];
                  final at = DateTime.tryParse('${s['scheduledAt']}')?.toLocal();
                  final students = ((s['students'] as List?) ?? []).cast<Map<String, dynamic>>();
                  final who = students.isEmpty
                      ? 'No students'
                      : students.length == 1
                          ? '${students.first['name']}'
                          : '${students.length} students';
                  final valid = s['valid'];
                  final status = '${s['status']}';
                  late final String label;
                  late final Color color;
                  if (valid == true) {
                    label = 'Counted';
                    color = Colors.green;
                  } else if (valid == false) {
                    label = 'Not counted';
                    color = Colors.red;
                  } else if (status == 'ongoing') {
                    label = 'Live';
                    color = Colors.blue;
                  } else {
                    label = 'Pending';
                    color = Colors.orange;
                  }
                  final stu = students.length == 1
                      ? ' · Student ${_mins(students.first['minutes'])} min'
                      : '';
                  return Card(
                    child: ListTile(
                      onTap: () => _openDetail(s),
                      title: Text(
                          '${at != null ? DateFormat('EEE, MMM d · h:mm a').format(at) : 'Session'} · $who'),
                      subtitle: Text(
                          '${s['sessionLength'] ?? '-'} min class · You ${_mins(s['teacherMinutes'])} min$stu'),
                      trailing: Text(label,
                          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SessionDetailSheet extends ConsumerStatefulWidget {
  const _SessionDetailSheet({required this.type, required this.id, required this.title});

  final String type;
  final String id;
  final String title;

  @override
  ConsumerState<_SessionDetailSheet> createState() => _SessionDetailSheetState();
}

class _SessionDetailSheetState extends ConsumerState<_SessionDetailSheet> {
  late final Future<Map<String, dynamic>> _future =
      ref.read(reportsRepositoryProvider).sessionDetail(widget.type, widget.id);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          final d = snap.data!;
          final students = ((d['students'] as List?) ?? []).cast<Map<String, dynamic>>();
          final events = ((d['events'] as List?) ?? []).cast<Map<String, dynamic>>();
          final tf = DateFormat('h:mm:ss a');
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('You stayed ${d['teacherMinutes'] ?? 0} min of ${d['sessionLength'] ?? '-'} min'),
              const SizedBox(height: 16),
              Text('Students', style: Theme.of(context).textTheme.titleMedium),
              if (students.isEmpty) const Text('No students recorded.'),
              ...students.map((s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${s['name']}'),
                    subtitle: Text('${s['minutes'] ?? 0} min in the call'),
                    trailing: Text('${s['attendance'] ?? '-'}'),
                  )),
              const SizedBox(height: 16),
              Text('Joined / left', style: Theme.of(context).textTheme.titleMedium),
              if (events.isEmpty)
                const Text('No join/leave times were recorded for this session.'),
              ...events.map((e) {
                final t = DateTime.tryParse('${e['timestamp']}')?.toLocal();
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    e['eventType'] == 'join' ? Icons.login : Icons.logout,
                    color: e['eventType'] == 'join' ? Colors.green : Colors.red,
                  ),
                  title: Text('${e['name']} ${e['eventType'] == 'join' ? 'joined' : 'left'}'),
                  trailing: Text(t != null ? tf.format(t) : ''),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _RangeTab extends ConsumerStatefulWidget {
  const _RangeTab();

  @override
  ConsumerState<_RangeTab> createState() => _RangeTabState();
}

class _RangeTabState extends ConsumerState<_RangeTab> {
  late DateTimeRange _range;
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    _load();
  }

  void _load() {
    setState(() {
      _future = ref.read(reportsRepositoryProvider).range(_ymd(_range.start), _ymd(_range.end));
    });
  }

  Future<void> _pick() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) {
      _range = picked;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d');
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.date_range),
          title: Text('${fmt.format(_range.start)} – ${fmt.format(_range.end)}'),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: _pick,
        ),
        Expanded(
          child: _AsyncBody<List<Map<String, dynamic>>>(
            future: _future,
            onRetry: _load,
            builder: (context, rows) {
              final t = rows.isNotEmpty ? rows.first : <String, dynamic>{};
              final days = ((t['days'] as List?) ?? [])
                  .cast<Map<String, dynamic>>()
                  .where((d) => _int(d['assigned']) > 0)
                  .toList()
                  .reversed
                  .toList();
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    _Stat('Students', '${_int(t['studentCount'])}'),
                    _Stat('Total classes', '${_int(t['totalClassesEntitled'])}'),
                    _Stat('Completed', '${_int(t['completed'])}', color: Colors.green),
                    _Stat('Pending', '${_int(t['pending'])}', color: Colors.orange),
                  ]),
                  const SizedBox(height: 20),
                  Text('Daily breakdown', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (days.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No classes in this range.')),
                    )
                  else
                    ...days.map((d) => Card(
                          child: ListTile(
                            title: Text(DateFormat('EEE, MMM d').format(DateTime.parse(d['date']))),
                            subtitle: Text(
                                '${_int(d['completed'])} completed · ${_int(d['pending']) + _int(d['ongoing'])} pending · ${_int(d['invalid'])} invalid'),
                            trailing: d['absent'] == true
                                ? const Chip(label: Text('Absent'))
                                : Text('${_int(d['assigned'])}'),
                          ),
                        )),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SalaryTab extends ConsumerStatefulWidget {
  const _SalaryTab();

  @override
  ConsumerState<_SalaryTab> createState() => _SalaryTabState();
}

class _SalaryTabState extends ConsumerState<_SalaryTab> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ref.read(reportsRepositoryProvider).mySalary(_ym(_month));
    });
  }

  void _shift(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    _month = next;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
            Text(DateFormat('MMMM y').format(_month), style: Theme.of(context).textTheme.titleMedium),
            IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Expanded(
          child: _AsyncBody<Map<String, dynamic>>(
            future: _future,
            onRetry: _load,
            builder: (context, s) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(spacing: 12, runSpacing: 12, children: [
                  _Stat('Classes taken', '${_int(s['classesTaken'])}'),
                  _Stat('Total earnings', _inr(s['totalAmount']), color: Colors.green),
                  _Stat('30-min classes', '${_int(s['count30'])}'),
                  _Stat('45-min classes', '${_int(s['count45'])}'),
                  _Stat('60-min classes', '${_int(s['count60'])}'),
                ]),
                const SizedBox(height: 12),
                const Text('Rates: ₹75 / 30 min · ₹100 / 45 min · ₹125 / 60 min unless your own rates are set. '
                    'Only valid classes (20+ minutes) are counted.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── student ─────────────────────────

class _StudentReport extends ConsumerStatefulWidget {
  const _StudentReport({required this.studentId});

  final String studentId;

  @override
  ConsumerState<_StudentReport> createState() => _StudentReportState();
}

class _StudentReportState extends ConsumerState<_StudentReport> with _LiveRefresh<_StudentReport> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
    startLiveRefresh();
  }

  @override
  void dispose() {
    stopLiveRefresh();
    super.dispose();
  }

  @override
  void reloadReport() => _load();

  void _load() {
    setState(() {
      _future = ref.read(reportsRepositoryProvider).studentReport(widget.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    listenForClassChanges();
    return Scaffold(
      appBar: AppBar(title: const Text('My Class Report')),
      body: _AsyncBody<Map<String, dynamic>>(
        future: _future,
        onRetry: _load,
        builder: (context, r) {
          final sessions = ((r['sessions'] as List?) ?? []).cast<Map<String, dynamic>>();
          final active = r['isActive'] == true;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(child: Text('${r['name'] ?? ''}', style: Theme.of(context).textTheme.titleLarge)),
                Chip(label: Text(active ? 'Active' : 'Inactive')),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _Stat('Classes taken', '${_int(r['totalCompleted'])}', color: Colors.green),
                _Stat('Classes pending', '${_int(r['totalRemaining'])}', color: Colors.orange),
                _Stat('Taken in app', '${_int(r['completedInLms'])}'),
                _Stat('Taken before app', '${_int(r['alreadyTaken'])}'),
              ]),
              const SizedBox(height: 20),
              Text('Recent sessions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (sessions.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No sessions yet.')))
              else
                ...sessions.take(30).map((s) {
                  final at = DateTime.tryParse('${s['scheduledAt']}')?.toLocal();
                  final status = s['valid'] == false ? 'Invalid' : '${s['status']}';
                  return Card(
                    child: ListTile(
                      title: Text(at != null ? DateFormat('MMM d, y · h:mm a').format(at) : 'Session'),
                      subtitle: Text('${s['sessionLength']} min · attended ${s['actualDuration'] ?? '-'} min'),
                      trailing: Text(status),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
