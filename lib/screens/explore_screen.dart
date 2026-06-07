import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../services/firestore_service.dart';
import '../services/class_provider.dart';
import '../services/auth_provider.dart';
import 'package:provider/provider.dart';
import 'lesson_detail_screen.dart';
import '../widgets/app_drawer.dart';
import 'add_lesson_screen.dart';
import 'schedule_upcoming_screen.dart';
import 'package:intl/intl.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Explore Archive'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search lessons...',
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.grey[200],
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<ClassProvider>(
        builder: (context, classProvider, _) {
          final targetClass = classProvider.currentClass;
          return StreamBuilder<List<Lesson>>(
        stream: _firestoreService.getLessonsStream(targetClass),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final lessons = snapshot.data ?? [];
          final filteredLessons = lessons
              .where((l) =>
                  l.topic.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  l.subtopic.toLowerCase().contains(_searchQuery.toLowerCase()))
              .toList();

          if (filteredLessons.isEmpty) {
            return const Center(child: Text('No lessons found.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredLessons.length,
            itemBuilder: (context, index) {
              final lesson = filteredLessons[index];
              return _buildLessonCard(lesson);
            },
          );
        }
      );
        }
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

  Widget _buildLessonCard(Lesson lesson) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LessonDetailScreen(lesson: lesson),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (lesson.imageUrl != null && lesson.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      lesson.imageUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image, size: 50, color: Colors.grey),
                    ),
                  ),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.currentUser?.isTeacher == true) {
                      return Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddLessonScreen(lessonToEdit: lesson),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          lesson.topic,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd').format(lesson.date),
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lesson.subtopic,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        child: Icon(Icons.person, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lesson.teacher,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
