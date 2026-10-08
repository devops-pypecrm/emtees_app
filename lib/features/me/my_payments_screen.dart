import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'me_provider.dart';

class MyPaymentsScreen extends ConsumerWidget {
  const MyPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myPaymentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Payments')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(myPaymentsProvider.notifier).refresh(),
        child: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, AsyncListState<Map<String, dynamic>> state) {
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
        icon: Icons.receipt_long_outlined,
        message: 'No payment records yet.',
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: state.items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _PaymentCard(payment: state.items[index]),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amount = payment['amount'];
    final status = payment['status']?.toString();
    final batch = payment['batch'];
    final batchName = batch is Map
        ? (batch['name'] ?? batch['title'])?.toString()
        : null;
    final dateRaw = payment['paidAt'] ?? payment['dueDate'] ?? payment['date'] ??
        payment['createdAt'];
    final date = dateRaw != null ? DateTime.tryParse(dateRaw.toString()) : null;
    final method = payment['method'] ?? payment['paymentMethod'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_outlined, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amount != null ? '₹$amount' : 'Payment',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (batchName != null) ...[
                    const SizedBox(height: 2),
                    Text(batchName, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  if (method != null) ...[
                    const SizedBox(height: 2),
                    Text('Method: $method',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                  if (date != null) ...[
                    const SizedBox(height: 2),
                    Text(DateFormat.yMMMd().format(date),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            if (status != null) _StatusBadge(status: status),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lower = status.toLowerCase();
    final isGood = lower.contains('paid') || lower.contains('success') ||
        lower.contains('complete');
    final isBad = lower.contains('fail') || lower.contains('overdue') ||
        lower.contains('pending');
    final color = isGood
        ? Colors.green
        : isBad
            ? scheme.error
            : scheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
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
        height: 84,
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
