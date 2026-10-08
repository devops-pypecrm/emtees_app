import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../me/me_provider.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(passwordChangeProvider.notifier).change(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
      Navigator.pop(context);
    } else {
      final error = ref.read(passwordChangeProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Could not change password.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(passwordChangeProvider).saving;

    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _currentController,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Current password',
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your current password' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New password',
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a new password';
                if (v.length < 6) return 'Must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureNew,
              decoration: const InputDecoration(labelText: 'Confirm new password'),
              validator: (v) {
                if (v != _newController.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: saving ? null : _submit,
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change password'),
            ),
          ],
        ),
      ),
    );
  }
}
