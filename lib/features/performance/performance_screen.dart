import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/phase3.dart';
import '../me/me_provider.dart';
import 'performance_provider.dart';

class PerformanceScreen extends ConsumerWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(performanceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Performance Reports')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(performanceProvider.notifier).refresh(),
        child: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AsyncListState<PerformanceReport> state) {
    if (state.loading && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(4, (_) => const _SkeletonCard()),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return _CenteredMessage(icon: Icons.error_outline, message: state.error!);
    }
    if (state.items.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.insights_outlined,
        message: 'No performance reports yet.',
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final report = state.items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(report.title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (report.summary != null) Text(report.summary!),
                    if (report.assessmentPeriod != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Period: ${report.assessmentPeriod}'),
                      ),
                    if (report.createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(DateFormat.yMMMd().format(report.createdAt!)),
                      ),
                  ],
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PerformanceHistoryScreen(report: report),
              )),
            ),
          ),
        );
      },
    );
  }
}

class PerformanceHistoryScreen extends ConsumerStatefulWidget {
  const PerformanceHistoryScreen({required this.report, super.key});

  final PerformanceReport report;

  @override
  ConsumerState<PerformanceHistoryScreen> createState() =>
      _PerformanceHistoryScreenState();
}

class _PerformanceHistoryScreenState
    extends ConsumerState<PerformanceHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final history = await ref
          .read(performanceRepositoryProvider)
          .fetchHistory(widget.report.id);
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load history.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.report.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _history.isEmpty
                  ? const Center(child: Text('No version history available.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = _history[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(entry.toString()),
                          ),
                        );
                      },
                    ),
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
        height: 90,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
