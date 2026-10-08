import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/phase3.dart';
import '../auth/auth_provider.dart';
import '../chat/chat_provider.dart';
import '../me/me_provider.dart';
import 'discipline_provider.dart';

class DisciplineScreen extends ConsumerWidget {
  const DisciplineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(disciplineProvider);
    final isTeacher = ref.watch(authProvider).user?.isTeacher == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Discipline Records')),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: () => _openFileReport(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('File Report'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(disciplineProvider.notifier).refresh(),
        child: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AsyncListState<DisciplineRecord> state) {
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
        icon: Icons.shield_outlined,
        message: 'No discipline records.',
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: state.items.length,
      itemBuilder: (context, index) {
        final record = state.items[index];
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
                      _LevelBadge(level: record.level),
                      const SizedBox(width: 8),
                      if (record.status != null)
                        Text(record.status!,
                            style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (record.userName != null)
                    Text('Student: ${record.userName}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (record.reason != null) ...[
                    const SizedBox(height: 4),
                    Text('Reason: ${record.reason}'),
                  ],
                  if (record.description != null &&
                      record.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(record.description!),
                  ],
                  if (record.reporterName != null) ...[
                    const SizedBox(height: 4),
                    Text('Filed by: ${record.reporterName}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                  if (record.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(DateFormat.yMMMd().format(record.createdAt!),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFileReport(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FileReportSheet(),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color color;
    switch (level) {
      case 'Suspension':
        color = scheme.error;
        break;
      case 'Final Warning':
        color = Colors.orange;
        break;
      default:
        color = scheme.secondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(level,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _FileReportSheet extends ConsumerStatefulWidget {
  const _FileReportSheet();

  @override
  ConsumerState<_FileReportSheet> createState() => _FileReportSheetState();
}

class _FileReportSheetState extends ConsumerState<_FileReportSheet> {
  final _reasonController = TextEditingController();
  final _descController = TextEditingController();
  final _userIdController = TextEditingController();
  final _batchController = TextEditingController();
  String _level = 'Warning';
  bool _submitting = false;
  bool _loadingContacts = true;
  List<dynamic> _students = [];
  dynamic _selectedStudent;

  static const _levels = ['Warning', 'Final Warning', 'Suspension'];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final contacts = await ref.read(chatRepositoryProvider).fetchContacts();
      if (!mounted) return;
      setState(() {
        _students = contacts.where((c) => c.role == 'student').toList();
        _loadingContacts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingContacts = false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _descController.dispose();
    _userIdController.dispose();
    _batchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final userId = _selectedStudent != null
        ? (_selectedStudent.id as String)
        : _userIdController.text.trim();
    if (userId.isEmpty ||
        _batchController.text.trim().isEmpty ||
        _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Fill in all required fields.')));
      return;
    }
    setState(() => _submitting = true);
    final ok = await ref.read(disciplineProvider.notifier).fileReport(
          userId: userId,
          batch: _batchController.text.trim(),
          level: _level,
          reason: _reasonController.text.trim(),
          description: _descController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not file report.')));
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
            Text('File Discipline Report', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_loadingContacts)
              const Center(child: CircularProgressIndicator())
            else if (_students.isNotEmpty)
              DropdownButtonFormField<dynamic>(
                initialValue: _selectedStudent,
                decoration: const InputDecoration(labelText: 'Student'),
                items: _students
                    .map((s) => DropdownMenuItem(value: s, child: Text(s.name as String)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedStudent = v),
              )
            else
              TextField(
                controller: _userIdController,
                decoration: const InputDecoration(labelText: 'Student user ID'),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _batchController,
              decoration: const InputDecoration(labelText: 'Batch ID'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _level,
              decoration: const InputDecoration(labelText: 'Level'),
              items: _levels
                  .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                  .toList(),
              onChanged: (v) => setState(() => _level = v ?? 'Warning'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('File Report'),
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
        height: 110,
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
