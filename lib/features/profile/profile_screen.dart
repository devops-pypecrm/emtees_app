import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/user.dart';
import '../auth/auth_provider.dart';
import '../updates/update_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final packageInfo = ref.watch(currentPackageInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit profile',
            onPressed: () => context.push('/edit-profile'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (user != null) _ProfileHeader(user: user),
          const SizedBox(height: 24),
          _SectionLabel('Account'),
          _InfoTile(icon: Icons.badge_outlined, label: 'Role', value: _roleLabel(user?.role)),
          if (user?.unionId != null)
            _InfoTile(icon: Icons.numbers, label: 'Union ID', value: user!.unionId!),
          if (user?.phone != null)
            _InfoTile(icon: Icons.phone_outlined, label: 'Phone', value: user!.phone!),
          if (user?.email != null)
            _InfoTile(icon: Icons.email_outlined, label: 'Email', value: user!.email!),
          const SizedBox(height: 8),
          _SectionLabel('App'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('App version'),
                  trailing: Text(
                    packageInfo.when(
                      data: (info) => 'v${info.version} (${info.buildNumber})',
                      loading: () => '...',
                      error: (_, __) => '—',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'teacher':
        return 'Teacher';
      case 'student':
        return 'Student';
      case 'admin':
        return 'Admin';
      case 'academic_head':
        return 'Academic Head';
      case 'super_admin':
        return 'Super Admin';
      default:
        return role ?? '—';
    }
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 28,
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: Theme.of(context).textTheme.titleLarge),
              if (user.username != null)
                Text(
                  '@${user.username}',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
