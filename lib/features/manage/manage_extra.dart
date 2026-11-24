import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_provider.dart';
import 'manage_widgets.dart';
import 'trpc.dart';

const _site = 'https://gecouncil.com';

const _reasons = {
  'initial': 'First assignment', 'student_request': 'Student request', 'teacher_resigned': 'Teacher resignation', 'teacher_health': 'Teacher health issues',
  'teacher_unavailable': 'Teacher unavailability', 'performance': 'Performance-related issues', 'administrative': 'Administrative decision', 'other': 'Other reasons',
};
String _why(Map r) => '${_reasons[r['reason']] ?? r['reason'] ?? '—'}${(r['reasonNote'] ?? '').toString().isEmpty ? '' : ' — ${r['reasonNote']}'}';

// ───────────── Teacher changes: log + per student ─────────────
class TeacherChangesScreen extends ConsumerStatefulWidget {
  const TeacherChangesScreen({super.key});
  @override
  ConsumerState<TeacherChangesScreen> createState() => _TeacherChangesState();
}

class _TeacherChangesState extends ConsumerState<TeacherChangesScreen> {
  List<Map<String, dynamic>>? _rows;
  String? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(trpcProvider).query('academic.changeHistory');
      if (mounted) setState(() { _rows = (d as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    // group by student, oldest first
    final by = <dynamic, List<Map<String, dynamic>>>{};
    for (final r in rows ?? const <Map<String, dynamic>>[]) { (by[r['studentId']] ??= []).add(r); }
    for (final l in by.values) { l.sort((a, b) => '${a['startedAt']}'.compareTo('${b['startedAt']}')); }
    final needle = _q.trim().toLowerCase();
    final log = <Map<String, dynamic>>[];
    for (final l in by.values) {
      for (var i = 0; i < l.length; i++) { log.add({...l[i], 'event': i == 0 ? 'Assigned' : 'Changed', 'from': i == 0 ? '' : l[i - 1]['teacher']}); }
    }
    log.sort((a, b) => '${b['startedAt']}'.compareTo('${a['startedAt']}'));
    final students = by.values.toList()..sort((a, b) => b.length.compareTo(a.length));
    bool match(String s) => needle.isEmpty || s.toLowerCase().contains(needle);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Teacher changes'), bottom: const TabBar(tabs: [Tab(text: 'Log'), Tab(text: 'Per student')])),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search student or teacher…', isDense: true, border: OutlineInputBorder()), onChanged: (v) => setState(() => _q = v)),
          ),
          Expanded(
            child: rows == null
                ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
                : TabBarView(children: [
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        for (final r in log.where((r) => match('${r['student']} ${r['teacher']} ${r['from']} ${r['enrollmentId']}')))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: RowCard(
                              title: '${r['student']}',
                              subtitle: r['event'] == 'Assigned' ? 'Assigned to ${r['teacher']}' : 'Changed from ${r['from']} to ${r['teacher']}',
                              lines: [_why(r), '${dateOnly(r['startedAt'])} · balance then ${r['classesAtStart'] ?? '—'}${(r['assignedBy'] ?? '').toString().isEmpty ? '' : ' · by ${r['assignedBy']}'}'],
                              trailing: StatusPill('${r['event']}', color: r['event'] == 'Assigned' ? Colors.teal : Colors.orange),
                            ),
                          ),
                        if (log.isEmpty) const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('No teacher assignments yet'))),
                      ]),
                    ),
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        for (final st in students.where((l) => match('${l.first['student']} ${l.map((e) => e['teacher']).join(' ')} ${l.first['enrollmentId']}')))
                          Padding(padding: const EdgeInsets.only(bottom: 10), child: _studentCard(context, st)),
                        if (students.isEmpty) const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('No students'))),
                      ]),
                    ),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _studentCard(BuildContext context, List<Map<String, dynamic>> st) {
    final changes = st.length - 1;
    final cur = st.firstWhere((e) => e['endedAt'] == null, orElse: () => st.last);
    return RowCard(
      title: '${st.first['student']}',
      subtitle: '${st.first['enrollmentId'] ?? ''} · now with ${cur['teacher']}',
      lines: [
        if (changes == 0) 'No change yet',
        for (var i = 1; i < st.length && i <= 2; i++) '${st[i - 1]['teacher']} → ${st[i]['teacher']} · ${_reasons[st[i]['reason']] ?? st[i]['reason']} · ${dateOnly(st[i]['startedAt'])}',
        if (changes > 2) '+${changes - 2} more — tap to view all',
      ],
      trailing: StatusPill('$changes change${changes == 1 ? '' : 's'}', color: changes == 0 ? Colors.grey : Colors.orange),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (c) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .7,
          builder: (c, sc) => ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
            Text('${st.first['student']}', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            Text('${st.first['enrollmentId'] ?? ''}'),
            const SizedBox(height: 16),
            for (var i = 0; i < st.length; i++) Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(i == 0 ? 'First teacher' : 'Teacher ${i + 1}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text('${st[i]['teacher']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text('${dateOnly(st[i]['startedAt'])} → ${st[i]['endedAt'] == null ? 'now' : dateOnly(st[i]['endedAt'])}${st[i]['classesAtStart'] != null ? ' · ${st[i]['classesAtStart']} classes left at start' : ''}'),
                if (i > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Changed from ${st[i - 1]['teacher']}. Reason: ${_why(st[i])}')),
                const Divider(),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────── Attendance sheet (month, per teacher) ─────────────
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});
  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceState();
}

class _AttendanceState extends ConsumerState<AttendanceScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _teacher = '';
  List teachers = [];
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  String get _m => '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final role = ref.read(authProvider).user?.role;
    if (role != 'teacher') {
      ref.read(trpcProvider).query('reports.teachers').then((d) { if (mounted) setState(() => teachers = d as List); }).catchError((_) {});
    }
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ref.read(trpcProvider).query('reports.attendanceMatrix', {'month': _m, 'teacherId': _teacher.isEmpty ? null : int.parse(_teacher)});
      if (mounted) setState(() { _data = Map<String, dynamic>.from(d as Map); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = ref.watch(authProvider).user?.role == 'teacher';
    final days = (_data?['days'] as int?) ?? 30;
    final blocks = ((_data?['teachers'] as List?) ?? []).whereType<Map>().toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Student attendance')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () { setState(() => _month = DateTime(_month.year, _month.month - 1)); _load(); }),
            Text(_m, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () { setState(() => _month = DateTime(_month.year, _month.month + 1)); _load(); }),
            const Spacer(),
            if (!isTeacher)
              Flexible(
                child: DropdownButton<String>(
                  value: _teacher,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [const DropdownMenuItem(value: '', child: Text('All teachers')), for (final t in teachers.whereType<Map>()) DropdownMenuItem(value: '${t['id']}', child: Text('${t['name']}', overflow: TextOverflow.ellipsis))],
                  onChanged: (v) { setState(() => _teacher = v ?? ''); _load(); },
                ),
              ),
          ]),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Row(children: [Icon(Icons.check, color: Colors.green, size: 16), Text(' present   '), Icon(Icons.close, color: Colors.red, size: 16), Text(' absent   (blank = no class)', style: TextStyle(fontSize: 12))])),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : blocks.isEmpty
                      ? const Center(child: Text('No attendance for this month'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(padding: const EdgeInsets.all(12), children: [for (final t in blocks) _teacherBlock(context, t, days)]),
                        ),
        ),
      ]),
    );
  }

  Widget _teacherBlock(BuildContext context, Map t, int days) {
    final students = (t['students'] as List).whereType<Map>().toList();
    const cell = 26.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${t['name']}  ·  ${students.length} students', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const SizedBox(width: 120, child: Text('Student', style: TextStyle(fontSize: 11, color: Colors.grey))),
                for (var d = 1; d <= days; d++) SizedBox(width: cell, child: Center(child: Text('$d', style: const TextStyle(fontSize: 10, color: Colors.grey)))),
                const SizedBox(width: 56, child: Center(child: Text('P / A', style: TextStyle(fontSize: 11, color: Colors.grey)))),
              ]),
              for (final s in students)
                Row(children: [
                  SizedBox(width: 120, child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('${s['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)))),
                  for (var d = 1; d <= days; d++)
                    SizedBox(
                      width: cell,
                      child: Center(
                        child: () {
                          final v = (s['days'] as Map?)?['$d'];
                          return v == 'present' ? const Icon(Icons.check, size: 16, color: Colors.green) : v == 'absent' ? const Icon(Icons.close, size: 16, color: Colors.red) : const SizedBox.shrink();
                        }(),
                      ),
                    ),
                  SizedBox(width: 56, child: Center(child: Text('${s['present']} / ${s['absent']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)))),
                ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────── Add student ─────────────
class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({super.key});
  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentState();
}

class _AddStudentState extends ConsumerState<AddStudentScreen> {
  final _c = <String, TextEditingController>{};
  TextEditingController c(String k, [String init = '']) => _c.putIfAbsent(k, () => TextEditingController(text: init));
  String dept = 'english', session = 'individual', method = 'Bank transfer', counsellor = '', teacher = '';
  PlatformFile? receipt;
  final extra = <PlatformFile>[];
  List counsellors = [], teachers = [];
  bool busy = false;

  bool get isAdmin => ['admin', 'super_admin'].contains(ref.read(authProvider).user?.role);
  bool get isCounsellor => ref.read(authProvider).user?.role == 'sales_executive';

  @override
  void initState() {
    super.initState();
    final api = ref.read(trpcProvider);
    if (!isCounsellor) api.query('staff.list', {'role': 'counsellor'}).then((d) { if (mounted) setState(() => counsellors = d as List); }).catchError((_) {});
    if (isAdmin) api.query('academic.teachersForDepartment', {}).then((d) { if (mounted) setState(() => teachers = d as List); }).catchError((_) {});
  }

  Widget _t(String k, String label, {bool number = false, int lines = 1, String hint = ''}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c(k), maxLines: lines, keyboardType: number ? TextInputType.number : null, decoration: InputDecoration(labelText: label, helperText: hint.isEmpty ? null : hint, border: const OutlineInputBorder())),
      );

  Widget _dd(String label, String value, Map<String, String> items, ValueChanged<String> on) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: items.containsKey(value) ? value : null,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => on(v ?? '')),
        ),
      );

  Widget _h(String t) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 10), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: .5)));

  Future<PlatformFile?> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'pdf'], withData: true);
    return r?.files.firstOrNull;
  }

  Future<void> _submit() async {
    final api = ref.read(trpcProvider);
    String v(String k) => c(k).text.trim();
    if (v('name').isEmpty || v('mobile').isEmpty) return snack(context, 'Name and mobile number are required');
    if (!isCounsellor && counsellor.isEmpty) return snack(context, 'Choose the counsellor who enrolled this student');
    if (v('timing').isEmpty) return snack(context, 'Preferred class timing is required');
    if (v('amount').isEmpty) return snack(context, 'Enter the amount paid');
    setState(() => busy = true);
    try {
      String? receiptUrl;
      final docs = <Map<String, String>>[];
      if (receipt != null) receiptUrl = await api.uploadDoc(receipt!);
      for (final f in extra) { docs.add({'name': f.name, 'url': await api.uploadDoc(f), 'type': 'other'}); }
      final r = await api.mutate('admissions.addStudent', {
        'name': v('name'), 'mobile': v('mobile'), 'whatsapp': v('whatsapp').isEmpty ? null : v('whatsapp'), 'email': v('email').isEmpty ? null : v('email'),
        'place': v('place').isEmpty ? null : v('place'), 'state': v('state').isEmpty ? null : v('state'), 'country': v('country').isEmpty ? null : v('country'),
        'parentName': v('parentName').isEmpty ? null : v('parentName'), 'parentPhone': v('parentPhone').isEmpty ? null : v('parentPhone'),
        'department': dept, 'sessionType': session, 'preferredTiming': v('timing'),
        'counsellorId': counsellor.isEmpty ? null : int.parse(counsellor),
        'amountPaid': num.tryParse(v('amount')) ?? 0, 'paymentDate': DateTime.now().toIso8601String().substring(0, 10), 'paymentMethod': method,
        'transactionRef': v('ref').isEmpty ? null : v('ref'), 'receiptUrl': receiptUrl, 'documents': docs,
        if (isAdmin) ...{
          'classes': int.tryParse(v('classes')) ?? 0, 'durationMinutes': int.tryParse(v('duration')) ?? 30, 'specialConditions': v('special').isEmpty ? null : v('special'),
          'teacherId': teacher.isEmpty ? null : int.parse(teacher), 'payPerClass': teacher.isEmpty ? null : num.tryParse(v('pay')),
        },
      });
      if (!mounted) return;
      await showDialog(context: context, builder: (d) => AlertDialog(
        title: const Text('Student added'),
        content: Text('Student ID: ${r['enrollmentId']}\nUsername: ${r['username']}\nPassword: ${r['password']}\n\n${r['status'] == 'payment_pending_verification' ? 'The payment now waits for finance to verify it.' : 'The student is ready.'}'),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Done'))],
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) snack(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add student')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _h('1. PERSONAL DETAILS'),
        _t('name', 'Full name *'), _t('mobile', 'Mobile number *', number: true), _t('whatsapp', 'WhatsApp number', number: true, hint: 'Leave empty if same as mobile'), _t('email', 'Email'),
        _t('place', 'Place'), _t('state', 'State'), _t('country', 'Country'), _t('parentName', 'Parent / guardian name'), _t('parentPhone', 'Parent / guardian phone', number: true),
        _h('2. ENROLMENT'),
        _dd('Course *', dept, const {'english': 'Spoken English', 'hindi': 'Spoken Hindi'}, (x) => dept = x),
        _dd('Session type *', session, const {'individual': 'Individual (one-to-one)', 'group': 'Group'}, (x) => session = x),
        _t('timing', 'Preferred class timing *', hint: 'e.g. 7 AM or Evening'),
        if (!isCounsellor) _dd('Enrolled by (counsellor) *', counsellor, {for (final x in counsellors.whereType<Map>()) '${x['id2'] ?? x['id']}': '${x['name']}'}, (x) => counsellor = x),
        _h('3. PAYMENT'),
        _t('amount', 'Amount paid (₹) *', number: true),
        _dd('Payment method', method, {for (final m in ['Bank transfer', 'UPI', 'Cash', 'Card', 'Cheque', 'Other']) m: m}, (x) => method = x),
        _t('ref', 'Transaction ID / reference'),
        OutlinedButton.icon(
          icon: const Icon(Icons.attach_file),
          label: Text(receipt == null ? 'Attach payment screenshot / receipt' : receipt!.name, overflow: TextOverflow.ellipsis),
          onPressed: () async { final f = await _pick(); if (f != null) setState(() => receipt = f); },
        ),
        const SizedBox(height: 8),
        for (final f in extra) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(f.name, overflow: TextOverflow.ellipsis), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => extra.remove(f)))),
        TextButton.icon(icon: const Icon(Icons.add), label: const Text('Add another document (ID proof etc.)'), onPressed: () async { final f = await _pick(); if (f != null) setState(() => extra.add(f)); }),
        if (isAdmin) ...[
          _h('4. CLASS ALLOCATION AND TEACHER'),
          _t('classes', 'Total classes', number: true, hint: 'Decided by you — no fixed fee-to-class rule'), _t('duration', 'Class duration (minutes)', number: true), _t('special', 'Special conditions'),
          _dd('Assign teacher now (optional)', teacher, {'': 'Later', for (final t in teachers.whereType<Map>()) '${t['id']}': '${t['name']} · ${t['students']} students'}, (x) => teacher = x),
          if (teacher.isNotEmpty) _t('pay', 'Teacher pay per class for this student (₹)', number: true),
        ] else
          const Padding(padding: EdgeInsets.only(top: 12), child: Text('After saving, finance verifies the payment. Then the academic head allocates classes, assigns the teacher and sets the teacher pay.', style: TextStyle(color: Colors.grey))),
        const SizedBox(height: 20),
        FilledButton(onPressed: busy ? null : _submit, child: busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Text('Create student')),
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ───────────── small helpers used around the app ─────────────
/// Counsellors get their own link; admin and academic head choose the counsellor. The link is copied for WhatsApp.
Future<void> createRegistrationLink(BuildContext context, WidgetRef ref) async {
  final api = ref.read(trpcProvider);
  final role = ref.read(authProvider).user?.role;
  try {
    Map<String, dynamic> input = {};
    if (role != 'sales_executive') {
      final list = (await api.query('staff.list', {'role': 'counsellor'})) as List;
      if (!context.mounted) return;
      final id = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (c) => ListView(shrinkWrap: true, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Which counsellor does this student belong to?', style: TextStyle(fontWeight: FontWeight.w600))),
          for (final x in list.whereType<Map>()) ListTile(title: Text('${x['name']}'), onTap: () => Navigator.pop(c, '${x['id2'] ?? x['id']}')),
        ]),
      );
      if (id == null) return;
      input = {'counsellorId': int.parse(id)};
    }
    final r = await api.mutate('admissions.createLink', input);
    await Clipboard.setData(ClipboardData(text: '$_site/register/${r['token']}'));
    if (context.mounted) snack(context, 'Registration link copied — send it to the student on WhatsApp');
  } catch (e) {
    if (context.mounted) snack(context, '$e');
  }
}

Future<void> showForgotPassword(BuildContext context, WidgetRef ref, String initial) async {
  final id = TextEditingController(text: initial), code = TextEditingController(), pw = TextEditingController();
  var sent = false, busy = false;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reset password', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(controller: id, decoration: const InputDecoration(labelText: 'Username, email or mobile number', border: OutlineInputBorder())),
          if (sent) ...[
            const SizedBox(height: 12),
            TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit code', border: OutlineInputBorder())),
            TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'New password (min 6 characters)', border: OutlineInputBorder())),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : () async {
                set(() => busy = true);
                final api = ref.read(trpcProvider);
                try {
                  if (!sent) {
                    final r = await api.mutate('auth.forgotPassword', {'identifier': id.text.trim()});
                    set(() => sent = true);
                    if (c.mounted) snack(c, '${r['message']}');
                  } else {
                    await api.mutate('auth.resetPassword', {'identifier': id.text.trim(), 'code': code.text.trim(), 'newPassword': pw.text});
                    if (c.mounted) { Navigator.pop(c); snack(context, 'Password changed. You can sign in now.'); }
                  }
                } catch (e) {
                  if (c.mounted) snack(c, '$e');
                } finally {
                  set(() => busy = false);
                }
              },
              child: Text(sent ? 'Change password' : 'Send reset code'),
            ),
          ),
          const Padding(padding: EdgeInsets.only(top: 8), child: Text('No email on your account? Ask an administrator to reset it.', style: TextStyle(fontSize: 12, color: Colors.grey))),
        ]),
      ),
    ),
  );
}

/// Teacher: remarks for a class and "report student absent".
Future<void> showClassNotes(BuildContext context, WidgetRef ref, String sessionId) async {
  final text = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(c).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Class notes', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(controller: text, maxLines: 3, decoration: const InputDecoration(labelText: 'Remarks about this class', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                try {
                  await ref.read(trpcProvider).mutate('lms.reportAbsence', {'sessionId': int.parse(sessionId), 'remarks': text.text.trim().isEmpty ? null : text.text.trim()});
                  if (c.mounted) { Navigator.pop(c); snack(context, 'Absence reported to the academic head'); }
                } catch (e) {
                  if (c.mounted) snack(c, '$e');
                }
              },
              child: const Text('Report absent'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () async {
                if (text.text.trim().isEmpty) return snack(c, 'Write a remark first');
                try {
                  await ref.read(trpcProvider).mutate('lms.addRemark', {'sessionId': int.parse(sessionId), 'remarks': text.text.trim()});
                  if (c.mounted) { Navigator.pop(c); snack(context, 'Remark saved'); }
                } catch (e) {
                  if (c.mounted) snack(c, '$e');
                }
              },
              child: const Text('Save remark'),
            ),
          ),
        ]),
      ]),
    ),
  );
}

/// Student: support phone / email set by the admin.
Future<void> showSupport(BuildContext context, WidgetRef ref) async {
  try {
    final cfg = await ref.read(trpcProvider).query('staff.publicConfig');
    if (!context.mounted) return;
    final phone = '${cfg['supportPhone'] ?? ''}', email = '${cfg['supportEmail'] ?? ''}';
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Need help?', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (phone.isEmpty && email.isEmpty) const Text('Support contact details have not been set yet. You can also send a request from My Requests.'),
          if (phone.isNotEmpty) ListTile(leading: const Icon(Icons.phone), title: Text(phone), onTap: () => launchUrl(Uri.parse('tel:$phone'))),
          if (email.isNotEmpty) ListTile(leading: const Icon(Icons.email_outlined), title: Text(email), onTap: () => launchUrl(Uri.parse('mailto:$email'))),
        ]),
      ),
    );
  } catch (e) {
    if (context.mounted) snack(context, '$e');
  }
}
