import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/class_provider.dart';
import '../services/tutorial_service.dart';
import '../services/update_service.dart';
import 'add_lesson_screen.dart';
import 'schedule_upcoming_screen.dart';
import 'explore_screen.dart';
import 'schedule_screen.dart';
import 'forum_screen.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final TutorialService _tutorialService = TutorialService();

  final List<Widget> _screens = [
    const ExploreScreen(),
    const ScheduleScreen(),
    const ForumScreen(),
    NotificationScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final classProvider = context.read<ClassProvider>();
      final user = authProvider.currentUser;
      final bool canAddContent = user != null && (user.isTeacher || user.isLeader);

      // Sync ClassProvider with user's enrolled classes
      if (user != null && user.enrolledClasses.isNotEmpty) {
        classProvider.setFromEnrolled(user.enrolledClasses);
      }

      _tutorialService.showTutorialIfFirstLaunch(context, canAddContent: canAddContent);
    });
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) UpdateService.checkForUpdates(context);
    });
  }

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
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Explore'),
          // Track the schedule tab
          BottomNavigationBarItem(
            icon: Icon(key: TutorialService.scheduleTabKey, Icons.calendar_month_outlined), 
            label: 'Schedule'
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: 'Forum'),
          // Track the notifications tab
          BottomNavigationBarItem(
            icon: Icon(key: TutorialService.notificationIconKey, Icons.notifications_none_outlined), 
            label: 'Alerts'
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.currentUser;
          if (user != null && (user.isTeacher || user.isLeader)) {
            return FloatingActionButton.extended(
              key: TutorialService.omniFabKey, // Track the FAB
              onPressed: () => _showOmniFabMenu(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Content'),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showOmniFabMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'What would you like to create?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.post_add, color: Colors.white)),
                  title: const Text('Post Completed Lesson'),
                  subtitle: const Text('Upload notes, summary & lab reports'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AddLessonScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.calendar_today, color: Colors.white)),
                  title: const Text('Schedule Upcoming Theory'),
                  subtitle: const Text('Add to timetable & notify class'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScheduleUpcomingScreen(isPractical: false)),
                    );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.science, color: Colors.white)),
                  title: const Text('Schedule Upcoming Practical'),
                  subtitle: const Text('Add laboratory schedule & notify class'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ScheduleUpcomingScreen(isPractical: true)),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
