import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../classes_provider.dart';
import 'status_badge.dart';

class ScheduleCard extends StatelessWidget {
  const ScheduleCard({super.key, required this.entry, required this.onTap});

  final ScheduleEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final scheduledAt = entry.scheduledAt;
    final timeLabel = scheduledAt == null
        ? ''
        : entry.isPast
            ? timeago.format(scheduledAt)
            : DateFormat('EEE, MMM d · h:mm a').format(scheduledAt.toLocal());

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: entry.isOneToOne
                      ? scheme.tertiaryContainer
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  entry.isOneToOne ? Icons.person_outline : Icons.groups_outlined,
                  color: entry.isOneToOne
                      ? scheme.onTertiaryContainer
                      : scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: entry.displayStatus),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (entry.subtitle.isNotEmpty) entry.subtitle,
                        if (timeLabel.isNotEmpty) timeLabel,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
