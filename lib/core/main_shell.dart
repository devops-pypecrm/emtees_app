import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_provider.dart';
import '../features/chat/chat_provider.dart';
import '../features/notifications/notifications_provider.dart';
import '../models/user.dart';

/// Global key so tab screens (each with their own inner [Scaffold]/AppBar)
/// can open the shared [Drawer] hosted on [MainShell]'s outer Scaffold via
/// `mainScaffoldKeyProvider.currentState?.openDrawer()` instead of relying on
/// `Scaffold.of(context)`, which would otherwise resolve to their own inner
/// Scaffold (which has no drawer) rather than this one.
final mainScaffoldKeyProvider = Provider<GlobalKey<ScaffoldState>>((ref) {
  return GlobalKey<ScaffoldState>();
});

/// Bottom-nav shell hosting the three main tabs (Home, Chat, Community) via
/// [StatefulShellRoute.indexedStack] so each tab keeps its own
/// scroll/navigation state when switching, plus a shared [Drawer] reachable
/// from all tabs holding the remaining navigation destinations.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late final NotchBottomBarController _notchController =
      NotchBottomBarController(index: widget.navigationShell.currentIndex);

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex != _notchController.index) {
      _notchController.jumpTo(widget.navigationShell.currentIndex);
    }
  }

  @override
  void dispose() {
    _notchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadChats = ref.watch(conversationsProvider).totalUnread;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: ref.watch(mainScaffoldKeyProvider),
      drawer: const _AppDrawer(),
      body: widget.navigationShell,
      bottomNavigationBar: AnimatedNotchBottomBar(
        notchBottomBarController: _notchController,
        color: scheme.surfaceContainerLow,
        notchColor: scheme.primary,
        showLabel: true,
        itemLabelStyle: TextStyle(color: scheme.onSurface, fontSize: 12),
        kIconSize: 24,
        kBottomRadius: 24,
        onTap: (index) {
          widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          );
        },
        bottomBarItems: [
          BottomBarItem(
            inActiveItem: Icon(Icons.home_outlined, color: scheme.onSurfaceVariant),
            activeItem: Icon(Icons.home, color: scheme.onPrimary),
            itemLabel: 'Home',
          ),
          BottomBarItem(
            inActiveItem: _badge(
              Icon(Icons.chat_bubble_outline, color: scheme.onSurfaceVariant),
              unreadChats,
            ),
            activeItem: _badge(
              Icon(Icons.chat_bubble, color: scheme.onPrimary),
              unreadChats,
            ),
            itemLabel: 'Chat',
          ),
          BottomBarItem(
            inActiveItem: Icon(Icons.forum_outlined, color: scheme.onSurfaceVariant),
            activeItem: Icon(Icons.forum, color: scheme.onPrimary),
            itemLabel: 'Community',
          ),
        ],
      ),
    );
  }

  Widget _badge(Widget icon, int count) {
    if (count <= 0) return icon;
    return Badge(
      label: Text(count > 9 ? '9+' : '$count'),
      child: icon,
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final unreadNotifications = ref.watch(notificationsProvider).unreadCount;
    final scheme = Theme.of(context).colorScheme;

    void go(String path) {
      Navigator.of(context).pop(); // close drawer
      context.push(path);
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _DrawerHeader(user: user),
            ListTile(
              leading: unreadNotifications > 0
                  ? Badge(
                      label: Text(
                          unreadNotifications > 9 ? '9+' : '$unreadNotifications'),
                      child: const Icon(Icons.notifications_outlined),
                    )
                  : const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () => go('/notifications'),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('My Batches'),
              onTap: () => go('/batches'),
            ),
            if (user?.isStudent == true)
              ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: const Text('My Requests'),
                onTap: () => go('/requests'),
              ),
            if (user?.isStudent == true)
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('My Attendance'),
                onTap: () => go('/attendance'),
              ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: Text(user?.isTeacher == true ? 'My Reports & Salary' : 'Reports'),
              onTap: () => go('/reports'),
            ),
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('Performance Reports'),
              onTap: () => go('/performance'),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Discipline Records'),
              onTap: () => go('/discipline'),
            ),
            if (user?.isStudent == true) ...[
              ListTile(
                leading: const Icon(Icons.star_outline),
                title: const Text('My Feedback'),
                onTap: () => go('/feedback'),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('My Payments'),
                onTap: () => go('/payments'),
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () => go('/profile'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Profile'),
              onTap: () => go('/edit-profile'),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Change Password'),
              onTap: () => go('/change-password'),
            ),
            ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text('Logout', style: TextStyle(color: scheme.error)),
              onTap: () => _confirmLogout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    Navigator.of(context).pop(); // close drawer first
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

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      color: scheme.surfaceContainerLow,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 24,
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _roleLabel(user?.role),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
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
        return role ?? '';
    }
  }
}
