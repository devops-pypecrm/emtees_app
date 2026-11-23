import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import 'manage_widgets.dart';
import 'trpc.dart';

const _siteOrigin = 'https://gecouncil.com';

// ───────────── Users: everyone in one list (admin, academic head) ─────────────
class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});
  @override
  ConsumerState<UsersScreen> createState() => _UsersState();
}

class _UsersState extends ConsumerState<UsersScreen> {
  String _role = '';
  static const _tabs = {
    '': 'All', 'student': 'Students', 'teacher': 'Teachers', 'counsellor': 'Counsellors',
    'academic_head': 'Heads', 'accountant': 'Accountants', 'admin': 'Admins',
  };

  @override
  Widget build(BuildContext context) {
    final isAdmin = ['admin', 'super_admin'].contains(ref.watch(authProvider).user?.role);
    return RemoteList(
      title: 'Users',
      path: 'staff.list',
      input: const {'includeStudents': true},
      empty: 'No users found',
      searchText: (r) => '${r['name']} ${r['phone']} ${r['username']} ${r['employeeId']}',
      pick: (r) => _role.isEmpty || r['role'] == _role || (_role == 'admin' && r['role'] == 'super_admin'),
      header: (c, all) => SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            for (final e in _tabs.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${e.value} ${all.where((u) => e.key.isEmpty || u['role'] == e.key || (e.key == 'admin' && u['role'] == 'super_admin')).length}'),
                  selected: _role == e.key,
                  onSelected: (_) => setState(() => _role = e.key),
                ),
              ),
          ],
        ),
      ),
      itemBuilder: (c, u, refresh) => RowCard(
        title: '${u['name']}',
        subtitle: '${pretty(u['role'] == 'counsellor' ? 'academic counsellor' : u['role'])} · ${u['phone'] ?? '—'}',
        lines: [if (isAdmin) 'Login: ${u['username'] ?? ''} / ${u['rawPassword'] ?? ''}'],
        trailing: StatusPill(pretty(u['status']), color: u['status'] == 'active' ? Colors.green : Colors.orange),
      ),
    );
  }
}

// ───────────── Students ─────────────
class StudentsScreen extends ConsumerWidget {
  const StudentsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RemoteList(
      title: 'Students',
      path: 'staff.students',
      input: const {'limit': 300},
      empty: 'No students found',
      searchText: (r) => '${r['name']} ${r['phone']} ${r['enrollment_id']}',
      itemBuilder: (c, s, refresh) => RowCard(
        title: '${s['name']}',
        subtitle: '${s['enrollment_id'] ?? '—'} · ${s['phone'] ?? ''}',
        lines: ['${s['department'] ?? s['course'] ?? ''}  ·  Teacher: ${s['teacher'] ?? 'not assigned'}', 'Counsellor: ${s['counsellor'] ?? '—'}  ·  Classes: ${s['allocated'] ?? 0}'],
        trailing: StatusPill(pretty(s['status']), color: s['status'] == 'active' ? Colors.green : Colors.orange),
        onTap: () => _studentSheet(context, ref, s),
      ),
    );
  }
}

Future<void> _studentSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> s) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => FutureBuilder(
      future: ref.read(trpcProvider).query('academic.studentOverview', {'studentUserId': s['id']}),
      builder: (c, snap) {
        final o = snap.data is Map ? Map<String, dynamic>.from(snap.data as Map) : null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: o == null
              ? SizedBox(height: 160, child: Center(child: snap.hasError ? Text('${snap.error}') : const CircularProgressIndicator()))
              : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${o['name']}', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                  Text('${o['enrollmentId'] ?? ''} · ${o['phone'] ?? ''}'),
                  const SizedBox(height: 14),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _Tile('Allocated', '${o['allocated']}'), _Tile('Completed', '${o['consumed']}'), _Tile('Balance', '${o['balance']}'),
                    _Tile('Validity', o['validityEndDate'] == null ? '—' : '${o['remainingDays']} days'),
                  ]),
                  const SizedBox(height: 14),
                  Text('Teacher: ${(o['teacher'] as Map?)?['name'] ?? 'not assigned'}'),
                  Text('Course: ${o['course'] ?? '—'}   Session: ${o['sessionType'] == 'group' ? 'Group' : 'Individual'}'),
                  Text('Last class: ${dateOnly(o['lastAttendedAt'])}   Next: ${dateOnly(o['nextClassAt'])}'),
                ]),
        );
      },
    ),
  );
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
        width: 96,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), Text(label, style: const TextStyle(fontSize: 11.5))]),
      );
}

// ───────────── Admissions (counsellor: own; others: all) ─────────────
class AdmissionsScreen extends ConsumerStatefulWidget {
  const AdmissionsScreen({super.key, this.onlyPending = false});
  final bool onlyPending;
  @override
  ConsumerState<AdmissionsScreen> createState() => _AdmissionsState();
}

class _AdmissionsState extends ConsumerState<AdmissionsScreen> {
  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.role ?? '';
    final canVerify = ['admin', 'super_admin', 'accountant'].contains(role);
    return RemoteList(
      title: widget.onlyPending ? 'Payments to verify' : 'Admissions',
      path: 'admissions.list',
      input: widget.onlyPending ? const {'status': 'payment_pending_verification'} : null,
      empty: widget.onlyPending ? 'No payments are waiting' : 'No admissions yet',
      searchText: (r) => '${r['fullName']} ${r['mobile']} ${r['status']}',
      fab: role == 'sales_executive'
          ? (c, refresh) => FloatingActionButton.extended(
                icon: const Icon(Icons.add_link),
                label: const Text('Registration link'),
                onPressed: () async {
                  try {
                    final r = await ref.read(trpcProvider).mutate('admissions.createLink', {});
                    final url = '$_siteOrigin/register/${r['token']}';
                    await Clipboard.setData(ClipboardData(text: url));
                    if (c.mounted) snack(c, 'Link copied — paste it in WhatsApp');
                    refresh();
                  } catch (e) {
                    if (c.mounted) snack(c, '$e');
                  }
                },
              )
          : null,
      itemBuilder: (c, a, refresh) {
        final status = '${a['status']}';
        final isLink = status == 'link_generated';
        return RowCard(
          title: isLink ? 'Link not used yet' : '${a['fullName']}',
          subtitle: isLink ? 'Created ${dateOnly(a['createdAt'])}' : '${a['mobile']} · ${a['department'] == 'hindi' ? 'Spoken Hindi' : 'Spoken English'}',
          lines: [if (!isLink) 'Paid ${rupees(a['amountPaid'])} by ${a['paymentMethod'] ?? '—'} · Counsellor: ${a['counsellorName'] ?? '—'}', if (a['duplicateOfUserId'] != null && a['duplicateResolved'] != true) '⚠ Mobile number already exists — admin review needed'],
          trailing: StatusPill(pretty(status)),
          onTap: isLink
              ? () async { await Clipboard.setData(ClipboardData(text: '$_siteOrigin/register/${a['token']}')); if (c.mounted) snack(c, 'Link copied'); }
              : (canVerify && status == 'payment_pending_verification')
                  ? () => _verify(c, ref, a, refresh)
                  : null,
        );
      },
    );
  }
}

Future<void> _verify(BuildContext context, WidgetRef ref, Map<String, dynamic> a, VoidCallback refresh) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${a['fullName']}', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Claimed ${rupees(a['amountPaid'])} · ${a['paymentMethod'] ?? ''} · ref ${a['transactionRef'] ?? '—'}'),
        Text('Counsellor: ${a['counsellorName'] ?? '—'}'),
        if ((a['receiptUrl'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Receipt: $_siteOrigin${a['receiptUrl']}', style: const TextStyle(fontSize: 12))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(c, 'reject'), child: const Text('Reject'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(onPressed: () => Navigator.pop(c, 'approve'), child: const Text('Approve'))),
        ]),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;
  final api = ref.read(trpcProvider);
  try {
    if (choice == 'approve') {
      final v = await askFields(context, 'Verified amount', [Fld('amount', 'Amount received (₹)', initial: '${num.tryParse('${a['amountPaid']}')?.toStringAsFixed(0) ?? ''}', number: true)], confirm: 'Approve payment');
      if (v == null) return;
      await api.mutate('admissions.verifyPayment', {'admissionId': a['id'], 'approve': true, 'verifiedAmount': num.tryParse(v['amount'] ?? '')});
      if (context.mounted) snack(context, 'Payment approved');
    } else {
      final v = await askFields(context, 'Reject payment', [const Fld('reason', 'Reason')], confirm: 'Reject');
      if (v == null || (v['reason'] ?? '').isEmpty) return;
      await api.mutate('admissions.verifyPayment', {'admissionId': a['id'], 'approve': false, 'reason': v['reason']});
      if (context.mounted) snack(context, 'Payment rejected');
    }
    refresh();
  } catch (e) {
    if (context.mounted) snack(context, '$e');
  }
}

// ───────────── Assign teachers ─────────────
class AssignScreen extends ConsumerWidget {
  const AssignScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RemoteList(
      title: 'Assign teachers',
      path: 'academic.awaitingAssignment',
      empty: 'No students are waiting for a teacher',
      searchText: (r) => '${r['fullName']} ${r['mobile']} ${r['preferredTiming']}',
      itemBuilder: (c, a, refresh) => RowCard(
        title: '${a['fullName']}',
        subtitle: '${a['mobile']} · ${a['department'] == 'hindi' ? 'Spoken Hindi' : 'Spoken English'}',
        lines: ['Preferred time: ${a['preferredTiming'] ?? '—'}  ·  ${a['sessionType'] == 'group' ? 'Group' : 'Individual'}'],
        trailing: a['studentUserId'] == null ? const StatusPill('Resolve duplicate', color: Colors.orange) : const Icon(Icons.chevron_right),
        onTap: a['studentUserId'] == null ? null : () => _pickTeacher(c, ref, a, refresh),
      ),
    );
  }
}

Future<void> _pickTeacher(BuildContext context, WidgetRef ref, Map<String, dynamic> a, VoidCallback refresh) async {
  final api = ref.read(trpcProvider);
  List teachers;
  try {
    teachers = (await api.query('academic.teachersForDepartment', {'department': a['department']})) as List;
  } catch (e) {
    if (context.mounted) snack(context, '$e');
    return;
  }
  if (!context.mounted) return;
  final picked = await showModalBottomSheet<Map>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .7,
      builder: (c, sc) => Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: Text('Choose a teacher for ${a['fullName']}', style: Theme.of(c).textTheme.titleMedium)),
        Expanded(
          child: ListView(controller: sc, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final t in teachers.whereType<Map>())
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RowCard(
                  title: '${t['name']}',
                  subtitle: '${t['students']} students',
                  lines: [_availability(t['availability'])],
                  onTap: () => Navigator.pop(c, t),
                ),
              ),
            if (teachers.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No teachers available for this course'))),
          ]),
        ),
      ]),
    ),
  );
  if (picked == null || !context.mounted) return;
  try {
    await api.mutate('academic.assignTeacher', {'studentUserId': a['studentUserId'], 'teacherId': picked['id'], 'admissionId': a['id'], 'preferredTiming': a['preferredTiming']});
    if (context.mounted) snack(context, 'Assigned to ${picked['name']}');
    refresh();
  } catch (e) {
    if (context.mounted) snack(context, '$e');
  }
}

String _availability(Object? av) {
  if (av is! Map) return 'Availability not set';
  final days = '${av['workingDays'] ?? av['working_days'] ?? ''}';
  final from = av['startTime'] ?? av['start_time'] ?? '';
  final to = av['endTime'] ?? av['end_time'] ?? '';
  return 'Available ${days.isEmpty ? '' : '$days · '}$from–$to';
}

// ───────────── Teacher pay ─────────────
class TeacherPayScreen extends StatelessWidget {
  const TeacherPayScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return RemoteList(
      title: 'Teacher pay',
      path: 'finance.settlementSummary',
      empty: 'No remuneration entries yet',
      searchText: (r) => '${r['name']}',
      itemBuilder: (c, r, refresh) => RowCard(
        title: '${r['name']}',
        subtitle: '${r['classes']} classes',
        lines: ['Pending approval ${rupees(r['pending'])}', 'Approved (to pay) ${rupees(r['approved'])}', 'Paid ${rupees(r['paid'])}'],
      ),
    );
  }
}

// ───────────── Requests ─────────────
class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RemoteList(
      title: 'Requests',
      path: 'academic.requests',
      empty: 'No requests',
      searchText: (r) => '${r['fromName']} ${r['type']} ${r['message']}',
      itemBuilder: (c, r, refresh) => RowCard(
        title: '${pretty(r['type'])} — ${r['fromName'] ?? ''}',
        subtitle: '${r['message'] ?? ''}',
        lines: [if ((r['response'] ?? '').toString().isNotEmpty) 'Reply: ${r['response']}', dateOnly(r['createdAt'])],
        trailing: StatusPill(pretty(r['status']), color: r['status'] == 'open' ? Colors.orange : Colors.green),
        onTap: r['status'] != 'open'
            ? null
            : () async {
                final v = await askFields(c, 'Reply to ${r['fromName']}', [const Fld('reply', 'Your reply')], confirm: 'Mark resolved');
                if (v == null) return;
                try {
                  await ref.read(trpcProvider).mutate('academic.resolveRequest', {'id': r['id'], 'status': 'resolved', 'response': v['reply']});
                  if (c.mounted) snack(c, 'Resolved');
                  refresh();
                } catch (e) {
                  if (c.mounted) snack(c, '$e');
                }
              },
      ),
    );
  }
}

// ───────────── Audit log (admin) ─────────────
class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return RemoteList(
      title: 'Audit log',
      path: 'academic.auditLog',
      input: const {'limit': 200},
      empty: 'Nothing recorded yet',
      searchText: (r) => '${r['action']} ${r['entity']} ${r['actorName']} ${r['reason']}',
      itemBuilder: (c, r, refresh) => RowCard(
        title: pretty(r['action']),
        subtitle: '${r['actorName'] ?? 'System'} · ${dateOnly(r['createdAt'])}',
        lines: ['${r['entity']} ${r['entityId'] ?? ''}', if ((r['reason'] ?? '').toString().isNotEmpty) 'Reason: ${r['reason']}'],
      ),
    );
  }
}

// ───────────── Overview (admin, head) ─────────────
class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: FutureBuilder(
        future: ref.read(trpcProvider).query('lms.headDashboard'),
        builder: (c, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = Map<String, dynamic>.from(snap.data as Map);
          final items = <(String, Object?)>[
            ('Active students', d['activeStudents']), ('New admissions (30 days)', d['newAdmissions']), ('Awaiting teacher', d['awaitingAssignment']),
            ('Completed today', d['completedToday']), ('Missed today', d['missedToday']), ('Open requests', d['pendingRequests']), ('Availability requests', d['pendingAvailability']),
          ];
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [for (final i in items) Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(c).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${i.$2 ?? 0}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)), Text(i.$1)]),
            )],
          );
        },
      ),
    );
  }
}
