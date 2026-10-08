import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'classes_provider.dart';

/// Teacher view of their 1-to-1 reschedule requests and how admin resolved them.
class RescheduleRequestsScreen extends ConsumerStatefulWidget {
  const RescheduleRequestsScreen({super.key});

  @override
  ConsumerState<RescheduleRequestsScreen> createState() => _RescheduleRequestsScreenState();
}

class _RescheduleRequestsScreenState extends ConsumerState<RescheduleRequestsScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = ref.read(classesRepositoryProvider).fetchRescheduleRequests();
    });
  }

  String _fmt(dynamic v) {
    final d = DateTime.tryParse('$v')?.toLocal();
    return d == null ? '-' : DateFormat('EEE, MMM d · h:mm a').format(d);
  }

  Color _color(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reschedule Requests')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snap.error}'),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            );
          }
          final rows = snap.data ?? [];
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: rows.isEmpty
                ? ListView(children: const [
                    SizedBox(height: 120),
                    Center(child: Text('No reschedule requests yet.')),
                  ])
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final r = rows[i];
                      final status = '${r['status']}';
                      final student = (r['session']?['student']?['name']) ?? 'Student';
                      return Card(
                        child: ListTile(
                          title: Text('$student · ${_fmt(r['proposedScheduledAt'])}'),
                          subtitle: Text([
                            if ('${r['reason'] ?? ''}'.isNotEmpty) '${r['reason']}',
                            if ('${r['adminRemarks'] ?? ''}'.isNotEmpty) 'Admin: ${r['adminRemarks']}',
                          ].join('\n')),
                          isThreeLine: true,
                          trailing: Chip(
                            label: Text(status),
                            backgroundColor: _color(status).withValues(alpha: 0.15),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
