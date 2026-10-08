import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/chat.dart';
import 'chat_provider.dart';

class NewConversationScreen extends ConsumerStatefulWidget {
  const NewConversationScreen({super.key});

  @override
  ConsumerState<NewConversationScreen> createState() =>
      _NewConversationScreenState();
}

class _NewConversationScreenState extends ConsumerState<NewConversationScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<ChatContact> _contacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load([String? search]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(chatRepositoryProvider);
      final contacts = await repo.fetchContacts(search: search);
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load contacts.';
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(value));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search contacts...',
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_contacts.isEmpty) {
      return const Center(child: Text('No contacts found.'));
    }
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      itemCount: _contacts.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
          ),
          title: Text(contact.name),
          subtitle: Text(contact.role ?? ''),
          onTap: () {
            context.pushReplacement('/chat/${contact.id}', extra: contact.name);
          },
        );
      },
    );
  }
}
