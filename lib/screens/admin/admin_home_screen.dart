import 'package:flutter/material.dart';
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

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const ExploreScreen(),
    ScheduleScreen(), // Removed const
    const ForumScreen(),
    NotificationScreen(), // Added without const
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: 'Forum'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none_outlined), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
