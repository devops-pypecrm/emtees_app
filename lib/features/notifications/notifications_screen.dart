import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/notification_item.dart';
import 'notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.items.isNotEmpty)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(NotificationsState state) {
    if (state.loading && state.items.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        itemBuilder: (_, __) => const _SkeletonTile(),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return _CenteredMessage(
        icon: Icons.error_outline,
        message: state.error!,
        actionLabel: 'Retry',
        onAction: () => ref.read(notificationsProvider.notifier).refresh(),
      );
    }

    if (state.items.isEmpty) {
      return const _CenteredMessage(
        icon: Icons.notifications_none,
        message: 'No notifications yet.',
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final item = state.items[index];
        return _NotificationTile(item: item);
      },
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) =>
          ref.read(notificationsProvider.notifier).delete(item),
      child: ListTile(
        tileColor: item.isRead
            ? null
            : scheme.primaryContainer.withValues(alpha: 0.18),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(_iconFor(item.type), color: scheme.onPrimaryContainer),
        ),
        title: Text(
          item.title,
          style: TextStyle(
            fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: Text(
          item.message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (item.createdAt != null)
              Text(
                timeago.format(item.createdAt!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (!item.isRead) ...[
              const SizedBox(height: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          ref.read(notificationsProvider.notifier).markRead(item);
          _showDetail(context, item);
        },
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'class':
      case 'live_class':
        return Icons.videocam_outlined;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'payment':
        return Icons.payments_outlined;
      case 'attendance':
        return Icons.fact_check_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  void _showDetail(BuildContext context, NotificationItem item) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(item.message, style: Theme.of(context).textTheme.bodyMedium),
            if (item.createdAt != null) ...[
              const SizedBox(height: 16),
              Text(
                timeago.format(item.createdAt!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 14,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
                  if (actionLabel != null) ...[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
