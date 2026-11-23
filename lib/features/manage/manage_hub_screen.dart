import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';
import 'manage_screens.dart';

/// Home for admin, academic head, accountant and counsellor logins: the same areas as the web portal, trimmed for a phone.
class ManageHubScreen extends ConsumerWidget {
  const ManageHubScreen({super.key});

  static List<(String, IconData, Widget Function())> _tiles(String role) {
    final overview = ('Overview', Icons.dashboard_outlined, () => const OverviewScreen() as Widget);
    final users = ('Users', Icons.groups_outlined, () => const UsersScreen() as Widget);
    final students = ('Students', Icons.school_outlined, () => const StudentsScreen() as Widget);
    final admissions = ('Admissions', Icons.how_to_reg_outlined, () => const AdmissionsScreen() as Widget);
    final payments = ('Payments to verify', Icons.payments_outlined, () => const AdmissionsScreen(onlyPending: true) as Widget);
    final assign = ('Assign teachers', Icons.person_add_alt_1_outlined, () => const AssignScreen() as Widget);
    final pay = ('Teacher pay', Icons.account_balance_wallet_outlined, () => const TeacherPayScreen() as Widget);
    final requests = ('Requests', Icons.mark_chat_unread_outlined, () => const RequestsScreen() as Widget);
    final audit = ('Audit log', Icons.shield_outlined, () => const AuditScreen() as Widget);
    switch (role) {
      case 'sales_executive':
        return [admissions, students];
      case 'accountant':
        return [payments, admissions, pay, students];
      case 'academic_head':
        return [overview, assign, students, requests, users];
      default:
        return [overview, admissions, payments, assign, students, requests, pay, users, audit];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final tiles = _tiles(user?.role ?? '');
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, ${user?.name.split(' ').first ?? ''}'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () => context.push('/notifications')),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') {
                await ref.read(authProvider.notifier).logout();
              } else {
                context.push(v);
              }
            },
            itemBuilder: (c) => const [
              PopupMenuItem(value: '/profile', child: Text('Profile')),
              PopupMenuItem(value: '/change-password', child: Text('Change password')),
              PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.25,
        children: [
          for (final t in tiles)
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => t.$3())),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(t.$2, size: 30, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 10),
                    Text(t.$1, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
