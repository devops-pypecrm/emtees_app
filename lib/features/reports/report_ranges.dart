import 'package:flutter/material.dart' show DateTimeRange;

/// The quick date choices on the teacher's Overview tab.
enum ReportPreset { today, yesterday, lastWeek, lastMonth, custom }

/// The four boxes on the Overview tab (assigned is every class in the range).
enum ClassBucket { assigned, completed, pending, notTaken }

/// Date range for a preset. "Last week" is the previous Monday-Sunday and "last month" is the
/// previous calendar month. [ReportPreset.custom] returns today (the caller supplies the range).
DateTimeRange rangeForPreset(ReportPreset p, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  switch (p) {
    case ReportPreset.today:
      return DateTimeRange(start: today, end: today);
    case ReportPreset.yesterday:
      final y = DateTime(today.year, today.month, today.day - 1);
      return DateTimeRange(start: y, end: y);
    case ReportPreset.lastWeek:
      final thisMonday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
      final start = DateTime(thisMonday.year, thisMonday.month, thisMonday.day - 7);
      return DateTimeRange(start: start, end: DateTime(start.year, start.month, start.day + 6));
    case ReportPreset.lastMonth:
      return DateTimeRange(
        start: DateTime(today.year, today.month - 1, 1),
        end: DateTime(today.year, today.month, 0), // day 0 = last day of the previous month
      );
    case ReportPreset.custom:
      return DateTimeRange(start: today, end: today);
  }
}

/// Where a class falls. Cancelled classes are never sent by the server.
///  completed = counted (teacher and student both reached the minimum time)
///  pending   = happening now, or scheduled for later
///  notTaken  = its time passed without a class, or it was held but ended under the minimum
/// Never returns [ClassBucket.assigned]; that box is simply every class.
ClassBucket bucketOfClass(Map<String, dynamic> r, DateTime now) {
  if (r['valid'] == true) return ClassBucket.completed;
  final status = '${r['status']}';
  if (status == 'completed') return ClassBucket.notTaken;
  if (status == 'ongoing') return ClassBucket.pending;
  final at = DateTime.tryParse('${r['scheduledAt']}')?.toLocal();
  if (at != null && at.isAfter(now)) return ClassBucket.pending;
  return ClassBucket.notTaken;
}
