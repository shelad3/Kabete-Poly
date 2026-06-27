import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/unread_badge_provider.dart';
import '../widgets/app_drawer.dart';
import 'incoming_lessons_screen.dart';
import 'full_timeline_screen.dart';
import 'quiz/quiz_list_screen.dart';
import 'grades/grade_report_screen.dart';
import 'cubes/house_list_screen.dart';
import 'cubes/my_bookings_screen.dart';
import 'add_lesson_screen.dart';
import 'schedule_upcoming_screen.dart';


class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Explore Archive'),
      ),
      body: Consumer<UnreadBadgeProvider>(
        builder: (context, badge, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      child: const Icon(Icons.schedule, color: Colors.blue),
                    ),
                    title: const Text('Incoming Lessons', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Upcoming practical & theory'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const IncomingLessonsScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepOrange.withValues(alpha: 0.1),
                      child: Stack(
                        children: [
                          const Icon(Icons.timeline, color: Colors.deepOrange),
                          if (badge.unreadForum > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    title: const Text('Full Timeline', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Past theory, practical, quizzes & completed lessons'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FullTimelineScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.withValues(alpha: 0.1),
                      child: const Icon(Icons.quiz, color: Colors.teal),
                    ),
                    title: const Text('Quizzes', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Practice assessments'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuizListScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.amber.withValues(alpha: 0.1),
                      child: const Icon(Icons.grade, color: Colors.amber),
                    ),
                    title: const Text('My Grades', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('View report card & performance'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GradeReportScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                      child: const Icon(Icons.workspaces, color: Colors.indigo),
                    ),
                    title: const Text('Book a Cubicle', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Reserve a lab workstation'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HouseListScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                      child: const Icon(Icons.book_online, color: Colors.deepPurple),
                    ),
                    title: const Text('My Bookings', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('View & cancel cubicle bookings'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.currentUser?.isTeacher == true) {
            return FloatingActionButton(
              onPressed: () => _showOmniFabMenu(context),
              child: const Icon(Icons.add),
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
