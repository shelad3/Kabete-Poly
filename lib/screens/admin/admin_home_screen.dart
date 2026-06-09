import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/class_provider.dart';
import '../../services/unread_badge_provider.dart';
import '../explore_screen.dart';
import '../schedule_screen.dart';
import '../forum_screen.dart';
import '../notification_screen.dart';
import '../settings_screen.dart';
import 'admin_dashboard_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  bool _badgeInitialized = false;

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const ExploreScreen(),
    const ScheduleScreen(),
    const ForumScreen(),
    NotificationScreen(),
    const SettingsScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_badgeInitialized) return;
    _badgeInitialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final classProv = context.read<ClassProvider>();
      final badge = context.read<UnreadBadgeProvider>();
      final user = auth.currentUser;
      if (user != null) {
        badge.init(
          auth.currentUserId,
          user.registrationNumber,
          user.enrolledClasses,
          classProv.currentClass,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final badge = context.watch<UnreadBadgeProvider>();
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 4) {
            context.read<UnreadBadgeProvider>().markNotificationsSeen([]);
          }
        },
        type: BottomNavigationBarType.fixed,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
          const BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Explore'),
          const BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Schedule'),
          const BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: 'Forum'),
          BottomNavigationBarItem(
            icon: badge.totalUnread > 0
                ? Badge(
                    label: Text(
                      badge.totalUnread > 99 ? '99+' : badge.totalUnread.toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                    child: const Icon(Icons.notifications_none_outlined),
                  )
                : const Icon(Icons.notifications_none_outlined),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
