import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../models/class_item.dart';
import '../classes_provider.dart';

/// Teacher-facing panel shown while hosting a live group class: lists
/// students who have requested to join the lobby, with approve/decline
/// actions and a bulk "Approve all".
class JoinRequestsPanel extends ConsumerStatefulWidget {
  const JoinRequestsPanel({super.key, required this.classId});

  final String classId;

  @override
  ConsumerState<JoinRequestsPanel> createState() => _JoinRequestsPanelState();
}

class _JoinRequestsPanelState extends ConsumerState<JoinRequestsPanel> {
  List<JoinRequest> _requests = [];
  bool _loading = true;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(classesRepositoryProvider);
    try {
      final requests = await repo.getJoinRequests(widget.classId);
      if (!mounted) return;
      setState(() {
        _requests = requests.where((r) => r.status == 'pending').toList();
        _loading = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _approve(String studentId) async {
    setState(() => _busyIds.add(studentId));
    try {
      await ref
          .read(classesRepositoryProvider)
          .approveJoinRequest(widget.classId, studentId);
      await _load();
    } finally {
      if (mounted) setState(() => _busyIds.remove(studentId));
    }
  }

  Future<void> _decline(String studentId) async {
    setState(() => _busyIds.add(studentId));
    try {
      await ref
          .read(classesRepositoryProvider)
          .declineJoinRequest(widget.classId, studentId);
      await _load();
    } finally {
      if (mounted) setState(() => _busyIds.remove(studentId));
    }
  }

  Future<void> _approveAll() async {
    setState(() => _loading = true);
    await ref.read(classesRepositoryProvider).approveAllJoinRequests(widget.classId);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_requests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_empty, color: scheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 10),
            Text('No pending join requests',
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Waiting to join (${_requests.length})',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton(onPressed: _approveAll, child: const Text('Approve all')),
          ],
        ),
        const SizedBox(height: 4),
        for (final r in _requests)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      r.studentName.isNotEmpty ? r.studentName[0].toUpperCase() : '?',
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.studentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (r.studentUnionId != null)
                          Text(r.studentUnionId!,
                              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (_busyIds.contains(r.studentId))
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    IconButton(
                      icon: Icon(Icons.close, color: scheme.error),
                      tooltip: 'Decline',
                      onPressed: () => _decline(r.studentId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Color(0xFF16A34A)),
                      tooltip: 'Approve',
                      onPressed: () => _approve(r.studentId),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
