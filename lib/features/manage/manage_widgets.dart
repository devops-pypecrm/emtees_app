import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'trpc.dart';

/// A list screen that loads from one tRPC query, with pull-to-refresh and a built-in search box.
class RemoteList extends ConsumerStatefulWidget {
  const RemoteList({
    super.key,
    required this.title,
    required this.path,
    required this.itemBuilder,
    this.input,
    this.empty = 'Nothing to show',
    this.searchable = true,
    this.header,
    this.fab,
    this.searchText,
    this.pick,
  });

  final String title;
  final String path;
  final Map<String, dynamic>? input;
  final String empty;
  final bool searchable;
  final Widget Function(BuildContext, Map<String, dynamic>, VoidCallback refresh) itemBuilder;
  final Widget Function(BuildContext, List<Map<String, dynamic>>)? header;
  final Widget Function(BuildContext, VoidCallback refresh)? fab;
  final String Function(Map<String, dynamic>)? searchText;
  /// Optional extra filter applied after loading (e.g. role tabs).
  final bool Function(Map<String, dynamic>)? pick;

  @override
  ConsumerState<RemoteList> createState() => RemoteListState();
}

class RemoteListState extends ConsumerState<RemoteList> {
  List<Map<String, dynamic>>? _rows;
  String? _error;
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RemoteList old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.input.toString() != widget.input.toString()) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await ref.read(trpcProvider).query(widget.path, widget.input);
      final list = d is List ? d : (d is Map ? (d['items'] as List? ?? []) : []);
      if (!mounted) return;
      setState(() { _rows = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _rows ?? [];
    final needle = _q.trim().toLowerCase();
    var rows = widget.pick == null ? all : all.where(widget.pick!).toList();
    if (needle.isNotEmpty) {
      rows = rows.where((r) => (widget.searchText?.call(r) ?? r.values.map((v) => v is Map || v is List ? '' : '$v').join(' ')).toLowerCase().contains(needle)).toList();
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: widget.fab?.call(context, _load),
      body: Column(children: [
        if (widget.header != null && _rows != null) widget.header!(context, all),
        if (widget.searchable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search…', isDense: true, border: OutlineInputBorder()),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading && _rows == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _rows == null
                    ? ListView(children: [Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(_error!, textAlign: TextAlign.center)))])
                    : rows.isEmpty
                        ? ListView(children: [Padding(padding: const EdgeInsets.all(48), child: Center(child: Text(needle.isEmpty ? widget.empty : 'No matches')))])
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (c, i) => widget.itemBuilder(c, rows[i], _load),
                          ),
          ),
        ),
      ]),
    );
  }
}

/// Rounded card used for each row.
class RowCard extends StatelessWidget {
  const RowCard({super.key, required this.title, this.subtitle, this.trailing, this.onTap, this.lines = const []});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (subtitle != null && subtitle!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13))),
                for (final l in lines.where((e) => e.isNotEmpty)) Padding(padding: const EdgeInsets.only(top: 2), child: Text(l, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5))),
              ]),
            ),
            if (trailing != null) trailing!,
          ]),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

String pretty(Object? s) => (s ?? '').toString().replaceAll('_', ' ');
String rupees(Object? n) => '₹${(num.tryParse('${n ?? 0}') ?? 0).toStringAsFixed(0)}';
String dateOnly(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '—';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
}

void snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

/// A bottom sheet with a few text fields and a confirm button. Returns the entered values or null.
class Fld {
  const Fld(this.key, this.label, {this.initial = '', this.number = false});
  final String key;
  final String label;
  final String initial;
  final bool number;
}

Future<Map<String, String>?> askFields(BuildContext context, String title, List<Fld> fields, {String confirm = 'Confirm'}) {
  final ctrls = {for (final f in fields) f.key: TextEditingController(text: f.initial)};
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(c).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        for (final f in fields) Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(controller: ctrls[f.key], keyboardType: f.number ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder())),
        ),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(c, {for (final e in ctrls.entries) e.key: e.value.text.trim()}), child: Text(confirm))),
      ]),
    ),
  );
}
