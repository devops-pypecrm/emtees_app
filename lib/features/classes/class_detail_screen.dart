import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/class_item.dart';
import '../auth/auth_provider.dart';
import '../realtime/socket_service.dart';
import 'classes_provider.dart';
import 'widgets/join_requests_panel.dart';
import 'widgets/status_badge.dart';

class ClassDetailScreen extends ConsumerStatefulWidget {
  const ClassDetailScreen({
    super.key,
    required this.id,
    required this.isOneToOne,
  });

  final String id;
  final bool isOneToOne;

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  bool _busy = false;
  String? _error;
  JoinStatus? _joinStatus;
  Timer? _pollTimer;

  ScheduleEntry? get _entry {
    final entries = ref.watch(scheduleProvider).entries;
    for (final e in entries) {
      if (e.id == widget.id && e.isOneToOne == widget.isOneToOne) return e;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (!widget.isOneToOne) {
      _refreshJoinStatus();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshJoinStatus() async {
    try {
      final status =
          await ref.read(classesRepositoryProvider).getJoinStatus(widget.id);
      if (!mounted) return;
      setState(() => _joinStatus = status);
    } on ApiException {
      // ignore, leave previous status
    }
  }

  void _startPollingJoinStatus() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _refreshJoinStatus();
      if (_joinStatus?.status == 'approved') {
        _pollTimer?.cancel();
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _teacherStartAndJoinGroup(ClassItem item) async {
    await _run(() async {
      final repo = ref.read(classesRepositoryProvider);
      if (item.status != 'live') {
        await repo.startClass(item.id);
      }
      final meeting = await repo.getMeetingDetails(item.id);
      if (!mounted) return;
      final user = ref.read(authProvider).user;
      context.push('/call/${meeting.roomName}', extra: {
        'jwt': meeting.jwt,
        'displayName': user?.name ?? 'Teacher',
        'isModerator': meeting.isModerator,
      });
    });
  }

  Future<void> _studentJoinGroup(ClassItem item) async {
    await _run(() async {
      final repo = ref.read(classesRepositoryProvider);
      final meeting = await repo.getMeetingDetails(item.id);
      if (!mounted) return;
      final user = ref.read(authProvider).user;
      context.push('/call/${meeting.roomName}', extra: {
        'jwt': meeting.jwt,
        'displayName': user?.name ?? 'Student',
        'isModerator': meeting.isModerator,
      });
    });
  }

  Future<void> _requestToJoin(ClassItem item) async {
    await _run(() async {
      await ref.read(classesRepositoryProvider).requestToJoin(item.id);
      await _refreshJoinStatus();
      _startPollingJoinStatus();
    });
  }

  Future<void> _teacherStartOneToOne(String sessionId) async {
    await _run(() async {
      final repo = ref.read(classesRepositoryProvider);
      final meeting = await repo.startOneToOne(sessionId);
      if (!mounted) return;
      final user = ref.read(authProvider).user;
      context.push('/call/${meeting.roomName}', extra: {
        'jwt': meeting.jwt,
        'displayName': user?.name ?? 'Teacher',
        'isModerator': meeting.isModerator,
        'oneToOneSessionId': sessionId,
      });
    });
  }

  Future<void> _studentJoinOneToOne(String sessionId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(classesRepositoryProvider);
      final meeting = await repo.joinOneToOne(sessionId);
      if (!mounted) return;
      final user = ref.read(authProvider).user;
      context.push('/call/${meeting.roomName}', extra: {
        'jwt': meeting.jwt,
        'displayName': user?.name ?? 'Student',
        'isModerator': meeting.isModerator,
        'oneToOneSessionId': sessionId,
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'FORBIDDEN') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(realtimeEventsProvider, (previous, next) {
      final event = next.valueOrNull;
      if (event == null) return;
      if ({'class:started', 'class:ended', 'class:updated'}.contains(event.type)) {
        ref.read(scheduleProvider.notifier).refresh();
        if (!widget.isOneToOne) _refreshJoinStatus();
      }
    });

    final entry = _entry;
    final user = ref.watch(authProvider).user;

    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Class')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isTeacher = user?.isTeacher ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(entry.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  StatusBadge(status: entry.displayStatus),
                  const Spacer(),
                  if (entry.scheduledAt != null)
                    Text(
                      DateFormat('EEE, MMM d · h:mm a')
                          .format(entry.scheduledAt!.toLocal()),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(entry.title, style: Theme.of(context).textTheme.headlineSmall),
              if (entry.subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  entry.subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
              if (entry.classItem?.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                Text(entry.classItem!.description!),
              ],
              const SizedBox(height: 24),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ..._buildActions(entry, isTeacher),
              if (!widget.isOneToOne && isTeacher && entry.isLive) ...[
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 12),
                JoinRequestsPanel(classId: entry.id),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildActions(ScheduleEntry entry, bool isTeacher) {
    if (widget.isOneToOne) {
      final session = entry.session!;
      if (entry.isPast) {
        return [const _InfoBanner(text: 'This session has ended.')];
      }
      if (isTeacher) {
        return [
          FilledButton.icon(
            onPressed: _busy ? null : () => _teacherStartOneToOne(session.id),
            icon: _busy
                ? const _ButtonSpinner()
                : const Icon(Icons.videocam_outlined),
            label: Text(entry.isLive ? 'Rejoin session' : 'Start session'),
          ),
        ];
      }
      // Student
      if (entry.isLive) {
        return [
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _studentJoinOneToOne(session.id),
            icon: _busy ? const _ButtonSpinner() : const Icon(Icons.videocam_outlined),
            label: const Text('Join session'),
          ),
        ];
      }
      return [const _InfoBanner(text: 'Waiting for your teacher to start this session.')];
    }

    // Group class
    final item = entry.classItem!;
    if (entry.isPast) {
      return [const _InfoBanner(text: 'This class has ended.')];
    }

    if (isTeacher) {
      return [
        FilledButton.icon(
          onPressed: _busy ? null : () => _teacherStartAndJoinGroup(item),
          icon: _busy ? const _ButtonSpinner() : const Icon(Icons.videocam_outlined),
          label: Text(entry.isLive ? 'Join class' : 'Start class'),
        ),
      ];
    }

    // Student flow
    if (!entry.isLive) {
      return [const _InfoBanner(text: 'The teacher hasn\'t started this class yet.')];
    }

    final status = _joinStatus?.status ?? 'none';
    if (status == 'approved') {
      return [
        FilledButton.icon(
          onPressed: _busy ? null : () => _studentJoinGroup(item),
          icon: _busy ? const _ButtonSpinner() : const Icon(Icons.videocam_outlined),
          label: const Text('Join class'),
        ),
      ];
    }
    if (status == 'pending') {
      return [
        const _InfoBanner(text: 'Waiting for the teacher to let you in…'),
        const SizedBox(height: 12),
        const Center(child: CircularProgressIndicator()),
      ];
    }
    if (status == 'declined') {
      return [
        const _InfoBanner(
          text: 'Your request to join was declined.',
          isError: true,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : () => _requestToJoin(item),
          child: const Text('Request to join again'),
        ),
      ];
    }
    return [
      FilledButton.icon(
        onPressed: _busy ? null : () => _requestToJoin(item),
        icon: _busy ? const _ButtonSpinner() : const Icon(Icons.front_hand_outlined),
        label: const Text('Request to join'),
      ),
    ];
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, this.isError = false});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isError ? scheme.errorContainer : scheme.surfaceContainerLow;
    final fg = isError ? scheme.onErrorContainer : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.info_outline, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: fg))),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }
}
