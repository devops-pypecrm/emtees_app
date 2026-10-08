import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/phase3.dart';
import '../auth/auth_provider.dart';
import '../me/me_provider.dart';
import 'materials_provider.dart';

class MaterialsScreen extends ConsumerWidget {
  const MaterialsScreen({required this.batchId, required this.batchName, super.key});

  final String batchId;
  final String batchName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(materialsProvider(batchId));
    final isTeacher = ref.watch(authProvider).user?.isTeacher == true;

    return Scaffold(
      appBar: AppBar(title: Text('Materials — $batchName')),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: () => _openCreate(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add Material'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(materialsProvider(batchId).notifier).refresh(),
        child: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AsyncListState<LearningMaterial> state) {
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
        icon: Icons.menu_book_outlined,
        message: 'No learning materials yet.',
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: state.items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _MaterialCard(material: state.items[index]),
      ),
    );
  }

  void _openCreate(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateMaterialSheet(batchId: batchId),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({required this.material});

  final LearningMaterial material;

  IconData get _icon {
    switch (material.type) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'video':
        return Icons.play_circle_outline;
      case 'image':
        return Icons.image_outlined;
      case 'voice':
        return Icons.mic_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLink = material.contentUrl != null && material.contentUrl!.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(material.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  if (material.description != null &&
                      material.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(material.description!,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                  if (hasLink) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openLink(context, material.contentUrl!),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open link.')));
      }
    }
  }
}

class _CreateMaterialSheet extends ConsumerStatefulWidget {
  const _CreateMaterialSheet({required this.batchId});

  final String batchId;

  @override
  ConsumerState<_CreateMaterialSheet> createState() => _CreateMaterialSheetState();
}

class _CreateMaterialSheetState extends ConsumerState<_CreateMaterialSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _urlController = TextEditingController();
  String _type = 'text';
  bool _submitting = false;

  static const _types = ['text', 'voice', 'image', 'video', 'pdf'];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final ok = await ref.read(materialsProvider(widget.batchId).notifier).create(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          type: _type,
          contentUrl: _urlController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not add material.')));
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
            Text('Add Learning Material', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: _types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? 'text'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Content link (optional)',
                hintText: 'https://...',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Add'),
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
        height: 90,
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
