// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/class_provider.dart';
import '../../services/unread_badge_provider.dart';
import '../../providers/feature_flag_provider.dart';
import '../explore_screen.dart';
import '../schedule_screen.dart';
import '../community_screen.dart';
import '../notification_screen.dart';
import '../settings_screen.dart';
import 'admin_dashboard_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminTab {
  const _AdminTab(this.flag, this.screen, this.icon, this.label);
  final String flag;
  final Widget screen;
  final IconData icon;
  final String label;
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  bool _badgeInitialized = false;

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

      badge.checkForPendingUpdates();
    });
  }

  List<_AdminTab> _buildTabs(FeatureFlagProvider flags, String? role) {
    const candidates = [
      _AdminTab(
        'admin_tab',
        AdminDashboardScreen(),
        Icons.admin_panel_settings,
        'Admin',
      ),
      _AdminTab('explore_tab', ExploreScreen(), Icons.explore_outlined, 'Explore'),
      _AdminTab(
        'timetable',
        ScheduleScreen(),
        Icons.calendar_month_outlined,
        'Schedule',
      ),
      _AdminTab('forum', CommunityScreen(), Icons.forum_outlined, 'Community'),
      _AdminTab(
        'notifications',
        NotificationScreen(),
        Icons.notifications_none_outlined,
        'Alerts',
      ),
      _AdminTab('settings_tab', SettingsScreen(), Icons.settings_outlined, 'Settings'),
    ];
    final tabs = <_AdminTab>[
      for (final tab in candidates)
        if (flags.isEnabledFor(tab.flag, role) &&
            !(tab.flag == 'admin_tab' && role != 'Official'))
          tab,
    ];
    if (tabs.isNotEmpty && tabs.length < 2) tabs.add(candidates.first);
    return tabs;
  }

  bool _showAlertsBadge(UnreadBadgeProvider badge) => badge.totalUnread > 0;

  @override
  Widget build(BuildContext context) {
    final badge = context.watch<UnreadBadgeProvider>();
    final flags = context.watch<FeatureFlagProvider>();
    final role = context.watch<AuthProvider>().currentUser?.role;
    final tabs = _buildTabs(flags, role);
    final notifIndex = tabs.indexWhere((t) => t.flag == 'notifications');

    var currentIndex = _currentIndex;
    if (currentIndex >= tabs.length) {
      currentIndex = tabs.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentIndex != currentIndex) {
          setState(() => _currentIndex = currentIndex);
        }
      });
    }

    return Scaffold(
      body: tabs[currentIndex].screen,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == notifIndex) {
            context.read<UnreadBadgeProvider>().markNotificationsSeen([]);
          }
        },
        type: BottomNavigationBarType.fixed,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        items: [
          for (final tab in tabs)
            if (tab.flag == 'notifications')
              BottomNavigationBarItem(
                icon: _showAlertsBadge(badge)
                    ? Badge(
                        label: Text(
                          badge.totalUnread > 99
                              ? '99+'
                              : badge.totalUnread.toString(),
                          style:
                              const TextStyle(fontSize: 10, color: Colors.white),
                        ),
                        child: Icon(tab.icon),
                      )
                    : Icon(tab.icon),
                label: tab.label,
              )
            else
              BottomNavigationBarItem(icon: Icon(tab.icon), label: tab.label),
        ],
      ),
    );
  }
}