import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../auth/auth_provider.dart';
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
        if (snap.connectionState != ConnectionState.done) {
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Reports'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Today'),
            Tab(text: 'Date range'),
            Tab(text: 'Salary'),
          ]),
        ),
        body: const TabBarView(children: [_TodayTab(), _RangeTab(), _SalaryTab()]),
      ),
    );
  }
}

class _TodayTab extends ConsumerStatefulWidget {
  const _TodayTab();

  @override
  ConsumerState<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<_TodayTab> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ref.read(reportsRepositoryProvider).daily(_ymd(DateTime.now()));
    });
  }

  @override
  Widget build(BuildContext context) {
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
              _Stat('Invalid (under 25 min)', '${_int(d['invalid'])}', color: Colors.red),
            ]),
            const SizedBox(height: 12),
            const Text('A class counts once you and the student have both stayed at least 25 minutes. '
                'A drop of up to 5 minutes is bridged if you rejoin.'),
          ],
        );
      },
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
                    'Only valid classes (25+ minutes) are counted.'),
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

class _StudentReportState extends ConsumerState<_StudentReport> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ref.read(reportsRepositoryProvider).studentReport(widget.studentId);
    });
  }

  @override
  Widget build(BuildContext context) {
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
