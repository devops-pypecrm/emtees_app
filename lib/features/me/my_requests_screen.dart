import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/my_data.dart';
import 'me_provider.dart';

const _requestTypes = ['hold', 'rejoin', 'batch_change', 'batch_removal'];

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myRequestsProvider.notifier).refresh(),
        child: _buildBody(context, ref, state),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewRequestSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Request'),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, AsyncListState<MyRequest> state) {
    if (state.loading && state.items.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => const _SkeletonCard(),
      );
    }
    if (state.error != null && state.items.isEmpty) {
      return _CenteredMessage(icon: Icons.error_outline, message: state.error!);
    }
    if (state.items.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.assignment_outlined,
        message: 'No requests yet.\nUse "New Request" to raise one.',
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: state.items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _RequestCard(request: state.items[index]),
      ),
    );
  }

  void _showNewRequestSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _NewRequestSheet(),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request});

  final MyRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = _statusStyle(context, request.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _typeLabel(request.requestType),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (request.reason != null && request.reason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(request.reason!, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (request.fromBatch != null || request.toBatch != null) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (request.fromBatch != null)
                    'From: ${request.fromBatch?['name'] ?? ''}',
                  if (request.toBatch != null)
                    'To: ${request.toBatch?['name'] ?? ''}',
                ].join('  ·  '),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (request.adminNote != null && request.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Admin note: ${request.adminNote}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
            ],
            if (request.requestedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM d, y · h:mm a')
                    .format(request.requestedAt!.toLocal()),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (request.status == 'pending') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Cancel request?'),
                        content: const Text(
                            'This will cancel your pending request.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('No'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Yes, cancel'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      ref.read(myRequestsProvider.notifier).cancelRequest(request.id);
                    }
                  },
                  child: const Text('Cancel request'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'hold':
        return 'Hold';
      case 'rejoin':
        return 'Rejoin';
      case 'batch_change':
        return 'Batch Change';
      case 'batch_removal':
        return 'Batch Removal';
      default:
        return type;
    }
  }

  (String, Color) _statusStyle(BuildContext context, String status) {
    switch (status) {
      case 'approved':
        return ('Approved', StatusColors.approved(context));
      case 'rejected':
        return ('Rejected', Theme.of(context).colorScheme.error);
      case 'cancelled':
        return ('Cancelled', StatusColors.cancelled(context));
      default:
        return ('Pending', StatusColors.pending(context));
    }
  }
}

class _NewRequestSheet extends ConsumerStatefulWidget {
  const _NewRequestSheet();

  @override
  ConsumerState<_NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends ConsumerState<_NewRequestSheet> {
  String _type = _requestTypes.first;
  String? _fromBatchId;
  String? _toBatchId;
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final batches = ref.watch(myBatchesProvider).items;
    final needsFromBatch = _type == 'batch_change' || _type == 'batch_removal';
    final needsToBatch = _type == 'batch_change' || _type == 'rejoin';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Request', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Request type'),
              items: _requestTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(_label(t))))
                  .toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            if (needsFromBatch) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _fromBatchId,
                decoration: const InputDecoration(labelText: 'From batch'),
                items: batches
                    .map((b) => DropdownMenuItem(
                          value: b.batchId ?? b.id,
                          child: Text(b.batchName),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _fromBatchId = value),
              ),
            ],
            if (needsToBatch) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _toBatchId,
                decoration: const InputDecoration(labelText: 'To batch'),
                items: batches
                    .map((b) => DropdownMenuItem(
                          value: b.batchId ?? b.id,
                          child: Text(b.batchName),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _toBatchId = value),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  String _label(String type) {
    switch (type) {
      case 'hold':
        return 'Hold';
      case 'rejoin':
        return 'Rejoin';
      case 'batch_change':
        return 'Batch Change';
      case 'batch_removal':
        return 'Batch Removal';
      default:
        return type;
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final ok = await ref.read(myRequestsProvider.notifier).createRequest(
          requestType: _type,
          fromBatchId: _fromBatchId,
          toBatchId: _toBatchId,
          reason: _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not submit request. Try again.')),
      );
    }
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
        height: 96,
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
