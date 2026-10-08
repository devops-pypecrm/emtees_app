import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/main_shell.dart';
import '../auth/auth_provider.dart';
import '../me/me_provider.dart';
import '../notifications/notifications_provider.dart';
import '../realtime/socket_service.dart';
import 'classes_provider.dart';
import 'widgets/schedule_card.dart';

enum _StatusFilter { all, live, upcoming, past, cancelled }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _dateFilter;
  _StatusFilter _statusFilter = _StatusFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty || _dateFilter != null || _statusFilter != _StatusFilter.all;

  List<ScheduleEntry> _applyFilters(List<ScheduleEntry> entries) {
    return entries.where((e) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = e.subtitle.toLowerCase().contains(q) ||
            e.title.toLowerCase().contains(q);
        if (!matches) return false;
      }
      if (_dateFilter != null) {
        final at = e.scheduledAt;
        if (at == null) return false;
        final local = at.toLocal();
        if (local.year != _dateFilter!.year ||
            local.month != _dateFilter!.month ||
            local.day != _dateFilter!.day) {
          return false;
        }
      }
      switch (_statusFilter) {
        case _StatusFilter.all:
          break;
        case _StatusFilter.live:
          if (!e.isLive) return false;
        case _StatusFilter.upcoming:
          if (!e.isScheduled) return false;
        case _StatusFilter.past:
          if (e.status != 'completed' && !(e.isPast && e.status != 'cancelled')) return false;
        case _StatusFilter.cancelled:
          if (e.status != 'cancelled') return false;
      }
      return true;
    }).toList();
  }

  List<ScheduleEntry> _sortedBy(
      List<ScheduleEntry> entries, bool Function(ScheduleEntry) test, {bool descending = false}) {
    final filtered = entries.where(test).toList();
    filtered.sort((a, b) {
      final cmp = (a.scheduledAt ?? DateTime.now())
          .compareTo(b.scheduledAt ?? DateTime.now());
      return descending ? -cmp : cmp;
    });
    return filtered;
  }
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final state = ref.watch(scheduleProvider);

    ref.listen(realtimeEventsProvider, (previous, next) {
      final event = next.valueOrNull;
      if (event == null) return;
      if ({'class:started', 'class:ended', 'class:updated'}
          .contains(event.type)) {
        ref.read(scheduleProvider.notifier).refresh();
      } else if (event.type == '1to1:incoming_call') {
        _showIncomingCallBanner(event.payload);
      }
    });

    final greeting = user?.isTeacher == true
        ? 'Welcome back'
        : 'Hi, ${user?.name.split(' ').first ?? ''}';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () =>
              ref.read(mainScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: Text(greeting),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(scheduleProvider.notifier).refresh(),
            ref.read(myBatchesProvider.notifier).refresh(),
            ref.read(notificationsProvider.notifier).refresh(),
          ]);
        },
        child: _buildBody(state, isTeacher: user?.isTeacher == true),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _dateFilter = picked);
  }

  void _showIncomingCallBanner(Map<String, dynamic> payload) {
    if (!mounted) return;
    final sessionId = payload['sessionId']?.toString();
    final title = payload['title']?.toString() ?? '1:1 session';
    final teacherName = payload['teacherName']?.toString() ?? 'Your teacher';
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.call, color: Colors.green),
        content: Text('$teacherName started "$title" — join now'),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
            },
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              if (sessionId != null) {
                context.push('/class/$sessionId?oneToOne=true');
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ScheduleState state, {required bool isTeacher}) {
    if (state.loading && state.entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SummaryRow(),
          const SizedBox(height: 20),
          ...List.generate(4, (_) => const _SkeletonCard()),
        ],
      );
    }

    if (state.error != null && state.entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const _SummaryRow(),
          const SizedBox(height: 40),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 56, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(state.error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => ref.read(scheduleProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (state.entries.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const _SummaryRow(),
          const SizedBox(height: 40),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_available_outlined,
                    size: 56, color: scheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('No classes scheduled',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Your live and upcoming classes will show up here.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final filtered = isTeacher ? _applyFilters(state.entries) : state.entries;
    final sections = <(String, List<ScheduleEntry>)>[
      ('Live now', _sortedBy(filtered, (e) => e.isLive)),
      ('Upcoming', _sortedBy(filtered, (e) => e.isScheduled)),
      (
        'Past',
        _sortedBy(filtered, (e) => e.isPast, descending: true).take(20).toList()
      ),
    ];
    final hasResults = sections.any((s) => s.$2.isNotEmpty);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const _SummaryRow(),
        if (isTeacher) ...[
          const SizedBox(height: 16),
          _TeacherFilterBar(
            controller: _searchController,
            dateFilter: _dateFilter,
            statusFilter: _statusFilter,
            hasActiveFilters: _hasActiveFilters,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onPickDate: _pickDate,
            onClearDate: () => setState(() => _dateFilter = null),
            onStatusChanged: (v) => setState(() => _statusFilter = v),
            onClearAll: () => setState(() {
              _searchController.clear();
              _searchQuery = '';
              _dateFilter = null;
              _statusFilter = _StatusFilter.all;
            }),
          ),
        ],
        if (isTeacher && !hasResults) ...[
          const SizedBox(height: 40),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off,
                    size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text('No sessions match these filters',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ],
        for (final (label, entries) in sections)
          if (entries.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ScheduleCard(
                  entry: entry,
                  onTap: () => context.push(
                    '/class/${entry.id}?oneToOne=${entry.isOneToOne}',
                  ),
                ),
              ),
          ],
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _SummaryRow extends ConsumerWidget {
  const _SummaryRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final batches = ref.watch(myBatchesProvider).items.length;
    final unread = ref.watch(notificationsProvider).unreadCount;
    final upcoming = ref.watch(scheduleProvider).upcoming.length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.groups_outlined,
            label: user?.isTeacher == true ? 'Batches' : 'My Batches',
            value: '$batches',
            onTap: () => context.push('/batches'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.notifications_outlined,
            label: 'Unread',
            value: '$unread',
            onTap: () => context.push('/notifications'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.event_outlined,
            label: 'Upcoming',
            value: '$upcoming',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: scheme.primary, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherFilterBar extends StatelessWidget {
  const _TeacherFilterBar({
    required this.controller,
    required this.dateFilter,
    required this.statusFilter,
    required this.hasActiveFilters,
    required this.onSearchChanged,
    required this.onPickDate,
    required this.onClearDate,
    required this.onStatusChanged,
    required this.onClearAll,
  });

  final TextEditingController controller;
  final DateTime? dateFilter;
  final _StatusFilter statusFilter;
  final bool hasActiveFilters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final ValueChanged<_StatusFilter> onStatusChanged;
  final VoidCallback onClearAll;

  static const _statusLabels = {
    _StatusFilter.all: 'All',
    _StatusFilter.live: 'Live',
    _StatusFilter.upcoming: 'Upcoming',
    _StatusFilter.past: 'Past',
    _StatusFilter.cancelled: 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by student name',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            filled: true,
            fillColor: scheme.surfaceContainerLow,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      onSearchChanged('');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: Text(
                  dateFilter == null
                      ? 'Date'
                      : DateFormat('MMM d').format(dateFilter!),
                ),
                avatar: const Icon(Icons.event_outlined, size: 16),
                selected: dateFilter != null,
                onSelected: (_) => onPickDate(),
              ),
              if (dateFilter != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onClearDate,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              for (final status in _StatusFilter.values) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_statusLabels[status]!),
                    selected: statusFilter == status,
                    onSelected: (_) => onStatusChanged(status),
                  ),
                ),
              ],
              if (hasActiveFilters)
                TextButton(
                  onPressed: onClearAll,
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
