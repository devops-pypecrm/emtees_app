import 'package:emtees_app/features/reports/report_ranges.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime d(int y, int m, int day) => DateTime(y, m, day);

  group('rangeForPreset', () {
    test('today and yesterday', () {
      final now = DateTime(2026, 10, 26, 15, 30);
      expect(rangeForPreset(ReportPreset.today, now).start, d(2026, 10, 26));
      expect(rangeForPreset(ReportPreset.today, now).end, d(2026, 10, 26));
      expect(rangeForPreset(ReportPreset.yesterday, now).start, d(2026, 10, 25));
      expect(rangeForPreset(ReportPreset.yesterday, now).end, d(2026, 10, 25));
    });

    test('yesterday across a month and a year boundary', () {
      expect(rangeForPreset(ReportPreset.yesterday, DateTime(2026, 11, 1)).start, d(2026, 10, 31));
      expect(rangeForPreset(ReportPreset.yesterday, DateTime(2027, 1, 1)).start, d(2026, 12, 31));
    });

    test('last week is the previous Monday to Sunday', () {
      // Mon 26 Oct 2026 -> previous week Mon 19 .. Sun 25 Oct
      final mon = rangeForPreset(ReportPreset.lastWeek, DateTime(2026, 10, 26));
      expect(mon.start, d(2026, 10, 19));
      expect(mon.end, d(2026, 10, 25));
      // Sunday 1 Nov 2026 is still in the week that started Mon 26 Oct -> previous week 19..25 Oct
      final sun = rangeForPreset(ReportPreset.lastWeek, DateTime(2026, 11, 1));
      expect(sun.start, d(2026, 10, 19));
      expect(sun.end, d(2026, 10, 25));
      expect(mon.start.weekday, DateTime.monday);
      expect(mon.end.weekday, DateTime.sunday);
    });

    test('last week across a year boundary', () {
      // Thu 7 Jan 2027 -> previous week Mon 28 Dec 2026 .. Sun 3 Jan 2027
      final r = rangeForPreset(ReportPreset.lastWeek, DateTime(2027, 1, 7));
      expect(r.start, d(2026, 12, 28));
      expect(r.end, d(2027, 1, 3));
    });

    test('last month', () {
      final oct = rangeForPreset(ReportPreset.lastMonth, DateTime(2026, 10, 26));
      expect(oct.start, d(2026, 9, 1));
      expect(oct.end, d(2026, 9, 30));
      final jan = rangeForPreset(ReportPreset.lastMonth, DateTime(2027, 1, 15));
      expect(jan.start, d(2026, 12, 1));
      expect(jan.end, d(2026, 12, 31));
      final mar = rangeForPreset(ReportPreset.lastMonth, DateTime(2026, 3, 10)); // February, 28 days in 2026
      expect(mar.start, d(2026, 2, 1));
      expect(mar.end, d(2026, 2, 28));
      final marLeap = rangeForPreset(ReportPreset.lastMonth, DateTime(2028, 3, 10)); // 2028 is a leap year
      expect(marLeap.end, d(2028, 2, 29));
    });
  });

  group('bucketOfClass', () {
    final now = DateTime(2026, 10, 26, 12, 0);
    String at(DateTime t) => t.toUtc().toIso8601String();
    Map<String, dynamic> row(String status, {bool? valid, DateTime? when}) => {
          'status': status,
          'valid': valid,
          'scheduledAt': at(when ?? now.subtract(const Duration(hours: 3))),
        };

    test('counted class is completed', () {
      expect(bucketOfClass(row('completed', valid: true), now), ClassBucket.completed);
    });

    test('counted while still live is also completed', () {
      expect(bucketOfClass(row('ongoing', valid: true), now), ClassBucket.completed);
    });

    test('held but under the minimum is not taken', () {
      expect(bucketOfClass(row('completed', valid: false), now), ClassBucket.notTaken);
    });

    test('live class that is not counted yet is pending', () {
      expect(bucketOfClass(row('ongoing', valid: null), now), ClassBucket.pending);
    });

    test('scheduled for later is pending', () {
      final r = row('scheduled', when: now.add(const Duration(hours: 2)));
      expect(bucketOfClass(r, now), ClassBucket.pending);
    });

    test('scheduled time passed and never held is not taken', () {
      expect(bucketOfClass(row('scheduled'), now), ClassBucket.notTaken);
      expect(bucketOfClass(row('rescheduled'), now), ClassBucket.notTaken);
    });

    test('reschedule requested for a future time is pending, for a past time not taken', () {
      expect(bucketOfClass(row('reschedule_request_pending', when: now.add(const Duration(days: 1))), now), ClassBucket.pending);
      expect(bucketOfClass(row('reschedule_request_pending'), now), ClassBucket.notTaken);
    });

    test('every class lands in exactly one of completed / pending / notTaken', () {
      final rows = [
        row('completed', valid: true),
        row('completed', valid: false),
        row('ongoing'),
        row('scheduled'),
        row('scheduled', when: now.add(const Duration(hours: 1))),
      ];
      final counts = {for (final b in ClassBucket.values) b: 0};
      for (final r in rows) {
        counts[bucketOfClass(r, now)] = counts[bucketOfClass(r, now)]! + 1;
      }
      expect(counts[ClassBucket.completed]! + counts[ClassBucket.pending]! + counts[ClassBucket.notTaken]!, rows.length);
      expect(counts[ClassBucket.assigned], 0);
    });
  });
}
