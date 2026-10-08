import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import 'me_repository.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _attendance = [];
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = MeRepository(ref.read(apiClientProvider));
      final results = await Future.wait([
        repo.fetchMyAttendance(),
        repo.fetchSessionSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _attendance = results[0] as List<Map<String, dynamic>>;
        _summary = results[1] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load attendance data.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Attendance')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      final scheme = Theme.of(context).colorScheme;
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 56, color: scheme.error),
                  const SizedBox(height: 16),
                  Text(_error!),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (_summary.isNotEmpty) _SummaryCards(summary: _summary),
        const SizedBox(height: 20),
        Text('Session history', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (_attendance.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No attendance records yet.')),
          )
        else
          ..._attendance.map((record) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AttendanceTile(record: record),
              )),
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final entries = summary.entries
        .where((e) => e.value is num || e.value is String)
        .take(6)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: entries.map((e) => _StatCard(label: _humanize(e.key), value: e.value)).toList(),
    );
  }

  String _humanize(String key) {
    final withSpaces = key.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final dynamic value;

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
          Text(
            '$value',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700, color: scheme.primary),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final status = record['status']?.toString() ?? 'unknown';
    final duration = record['duration'];
    final dateRaw = record['date'] ?? record['joinedAt'] ?? record['createdAt'];
    DateTime? date;
    if (dateRaw != null) date = DateTime.tryParse(dateRaw.toString());

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _statusColor(status).withValues(alpha: 0.15),
          child: Icon(_statusIcon(status), color: _statusColor(status)),
        ),
        title: Text(
          date != null
              ? DateFormat('MMM d, y').format(date.toLocal())
              : 'Session',
        ),
        subtitle: Text([
          status,
          if (duration != null) '${duration}min',
        ].join(' · ')),
        trailing: date != null
            ? Text(DateFormat('h:mm a').format(date.toLocal()),
                style: Theme.of(context).textTheme.bodySmall)
            : null,
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'late':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle_outline;
      case 'absent':
        return Icons.cancel_outlined;
      case 'late':
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
  }
}
