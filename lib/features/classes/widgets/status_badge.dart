import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _resolve(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'live' || status == 'live_now') ...[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  /// Mirrors the web app's exact badge labels (Classes.tsx/Dashboard.tsx):
  /// "🔴 Live" for live, "STARTING SOON"/"UPCOMING" for the two scheduled
  /// sub-states, "Scheduled" for a plain scheduled item with no computed
  /// sub-state yet, and the usual completed/cancelled/rescheduled labels.
  (String, Color) _resolve(BuildContext context, String status) {
    switch (status) {
      case 'live':
      case 'live_now':
        return ('🔴 Live', StatusColors.live(context));
      case 'starting_soon':
        return ('STARTING SOON', StatusColors.pending(context));
      case 'upcoming':
        return ('UPCOMING', StatusColors.scheduled(context));
      case 'past':
        return ('Ended', StatusColors.completed(context));
      case 'scheduled':
        return ('Scheduled', StatusColors.scheduled(context));
      case 'reschedule_request_pending':
        return ('Reschedule pending', StatusColors.pending(context));
      case 'completed':
        return ('Completed', StatusColors.completed(context));
      case 'cancelled':
        return ('Cancelled', StatusColors.cancelled(context));
      case 'rescheduled':
        return ('Rescheduled', StatusColors.pending(context));
      default:
        return (status, StatusColors.completed(context));
    }
  }
}
