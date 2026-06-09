import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/class_provider.dart';
import '../services/update_service.dart';
import 'onboarding_screen.dart';
import 'add_lesson_screen.dart';
import 'schedule_upcoming_screen.dart';
import 'explore_screen.dart';
import 'schedule_screen.dart';
import 'forum_screen.dart';
import 'notification_screen.dart';
import 'settings_screen.dart';
import 'quiz/quiz_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

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
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final classProvider = context.read<ClassProvider>();
      final user = authProvider.currentUser;

      // Sync ClassProvider with user's enrolled classes
      if (user != null && user.enrolledClasses.isNotEmpty) {
        classProvider.setFromEnrolled(user.enrolledClasses);
      }

      // Auto-check for updates on startup
      UpdateService.checkForUpdates(context);

      OnboardingScreen.hasSeen().then((seen) {
        if (!seen && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        }
      });
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) UpdateService.checkForUpdates(context);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        type: BottomNavigationBarType.fixed,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Explore'),
          const BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), label: 'Schedule'),
          const BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: 'Forum'),
          const BottomNavigationBarItem(icon: Icon(Icons.notifications_none_outlined), label: 'Alerts'),
          const BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.currentUser;
          if (user != null && (user.isTeacher || user.isLeader)) {
            return FloatingActionButton.extended(
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
                ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.quiz, color: Colors.white)),
                  title: const Text('Create Quiz'),
                  subtitle: const Text('Build multiple-choice assessments'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizListScreen()),
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
