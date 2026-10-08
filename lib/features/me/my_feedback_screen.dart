import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../models/my_data.dart';
import '../../models/phase3.dart';
import 'me_provider.dart';

class MyFeedbackScreen extends ConsumerWidget {
  const MyFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myFeedbackProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Feedback')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openGiveFeedback(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Give Feedback'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myFeedbackProvider.notifier).refresh(),
        child: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AsyncListState<FeedbackItem> state) {
    if (state.loading && state.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(3, (_) => const _SkeletonCard()),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return _CenteredMessage(icon: Icons.error_outline, message: state.error!);
    }
    if (state.items.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.star_outline,
        message: 'You have not given any feedback yet.',
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 96),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final item = state.items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.teacherName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Row(
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < item.rating ? Icons.star : Icons.star_border,
                            size: 18,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.batchName,
                      style: Theme.of(context).textTheme.bodySmall),
                  if (item.comment != null && item.comment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(item.comment!),
                  ],
                  if (item.createdAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      DateFormat.yMMMd().format(item.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openGiveFeedback(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _GiveFeedbackSheet(),
    );
  }
}

class _GiveFeedbackSheet extends ConsumerStatefulWidget {
  const _GiveFeedbackSheet();

  @override
  ConsumerState<_GiveFeedbackSheet> createState() => _GiveFeedbackSheetState();
}

class _GiveFeedbackSheetState extends ConsumerState<_GiveFeedbackSheet> {
  final _commentController = TextEditingController();
  int _rating = 5;
  MyBatch? _selectedBatch;
  bool _submitting = false;
  List<MyBatch> _batches = [];
  bool _loadingBatches = true;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    final batches = ref.read(myBatchesProvider).items;
    if (batches.isNotEmpty) {
      setState(() {
        _batches = batches;
        _loadingBatches = false;
      });
      return;
    }
    await ref.read(myBatchesProvider.notifier).refresh();
    if (!mounted) return;
    setState(() {
      _batches = ref.read(myBatchesProvider).items;
      _loadingBatches = false;
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String? _teacherIdOf(MyBatch batch) {
    final teacher = batch.batch?['teacher'];
    if (teacher is Map) return teacher['id']?.toString();
    return null;
  }

  Future<void> _submit() async {
    final batch = _selectedBatch;
    if (batch == null) return;
    final teacherId = _teacherIdOf(batch);
    if (teacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This batch has no assigned teacher.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(myFeedbackProvider.notifier).submitFeedback(
            teacherId: teacherId,
            batchId: batch.batchId ?? batch.id,
            rating: _rating,
            comment: _commentController.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted. Thank you!')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit feedback.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Give Feedback', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_loadingBatches)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<MyBatch>(
                initialValue: _selectedBatch,
                decoration: const InputDecoration(labelText: 'Batch & teacher'),
                items: _batches
                    .map((b) => DropdownMenuItem(
                          value: b,
                          child: Text(
                            '${b.batchName}${b.teacherName != null ? ' — ${b.teacherName}' : ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedBatch = v),
              ),
            const SizedBox(height: 16),
            Text('Rating', style: Theme.of(context).textTheme.labelLarge),
            Row(
              children: List.generate(
                5,
                (i) => IconButton(
                  icon: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => _rating = i + 1),
                ),
              ),
            ),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  (_selectedBatch == null || _submitting) ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit'),
            ),
          ],
        ),
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
