import 'package:flutter/material.dart';
import '../models/lesson.dart';
import '../models/schedule_item.dart';
import '../models/feed_item.dart';
import '../services/firestore_service.dart';
import '../services/class_provider.dart';
import '../services/auth_provider.dart';
import 'package:provider/provider.dart';
import 'lesson_detail_screen.dart';
import '../widgets/app_drawer.dart';
import '../widgets/shimmer_loading.dart';
import 'add_lesson_screen.dart';
import 'schedule_upcoming_screen.dart';
import 'quiz/quiz_list_screen.dart';
import 'grades/grade_report_screen.dart';
import 'cubes/house_list_screen.dart';
import 'cubes/my_bookings_screen.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
                hintText: 'Search lessons and timeline...',
                prefixIcon: const Icon(Icons.search),
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
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
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
              ),
              const SizedBox(height: 4),
              Card(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
              Expanded(
                child: _buildTimeline(targetClass),
              ),
            ],
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

  Widget _buildTimeline(String targetClass) {
    final lessonsStream = _firestoreService.getLessonsStream(targetClass);
    final scheduleStream = _firestoreService.getScheduleTimelineStream(targetClass);

    return StreamBuilder<List<Lesson>>(
      stream: lessonsStream,
      builder: (context, lessonSnap) {
        return StreamBuilder<List<ScheduleItem>>(
          stream: scheduleStream,
          builder: (context, scheduleSnap) {
            if (lessonSnap.connectionState == ConnectionState.waiting &&
                scheduleSnap.connectionState == ConnectionState.waiting) {
              return const ShimmerExploreList();
            }

            final lessons = lessonSnap.data ?? [];
            final schedules = scheduleSnap.data ?? [];

            final List<FeedItem> feed = [
              ...lessons.map(FeedItem.lesson),
              ...schedules.map(FeedItem.schedule),
            ];

            feed.sort((a, b) => b.date.compareTo(a.date));

            if (_searchQuery.isNotEmpty) {
              feed.removeWhere((item) {
                final q = _searchQuery.toLowerCase();
                if (item.type == 'lesson') {
                  final l = item.lesson!;
                  return !l.topic.toLowerCase().contains(q) && !l.subtopic.toLowerCase().contains(q);
                }
                return !item.schedule!.subject.toLowerCase().contains(q);
              });
            }

            if (feed.isEmpty) {
              return Center(
                child: Text(_searchQuery.isEmpty ? 'No activity yet.' : 'No matches found.'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: feed.length,
              itemBuilder: (context, index) {
                final item = feed[index];
                if (item.type == 'lesson') {
                  return _buildLessonCard(item.lesson!);
                }
                return _buildScheduleCard(item.schedule!);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildScheduleCard(ScheduleItem item) {
    final isPast = item.date.isBefore(DateTime.now());
    final color = item.color;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (item.attachmentUrls.isNotEmpty) {
            _showAttachments(context, item);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  item.description == 'Practical Lab Session' ? Icons.science : Icons.book,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.subject,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPast ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPast ? 'Completed' : 'Upcoming',
                            style: TextStyle(
                              fontSize: 11,
                              color: isPast ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.room}  •  ${item.startTime} - ${item.endTime}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy').format(item.date),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    if (item.attachmentUrls.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.attach_file, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            '${item.attachmentUrls.length} attachment(s)',
                            style: TextStyle(color: Colors.grey[400], fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.currentUser?.isTeacher != true) return const Icon(Icons.chevron_right, size: 18, color: Colors.grey);
                  return PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'delete') _confirmDeleteSchedule(item);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'delete', child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red, size: 20),
                        title: Text('Delete', style: TextStyle(color: Colors.red, fontSize: 14)),
                        dense: true,
                      )),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteSchedule(ScheduleItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule Item'),
        content: Text('Permanently delete "${item.subject}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _firestoreService.deleteScheduleItem(item.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Schedule item deleted'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAttachments(BuildContext context, ScheduleItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attachments for ${item.subject}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...List.generate(item.attachmentUrls.length, (i) {
              return ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.blue),
                title: Text(
                  i < item.attachmentNames.length ? item.attachmentNames[i] : 'Document ${i + 1}',
                ),
                trailing: const Icon(Icons.open_in_new, size: 16),
                onTap: () async {
                  final uri = Uri.parse(item.attachmentUrls[i]);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              );
            }),
          ],
        ),
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
                Hero(
                  tag: 'lesson_img_${lesson.id}',
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: lesson.imageUrl != null && lesson.imageUrl!.isNotEmpty
                        ? Image.network(
                            lesson.imageUrl!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            height: 180,
                            width: double.infinity,
                            color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
                            child: Icon(Icons.image, size: 50, color: Theme.of(context).disabledColor),
                          ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      if (auth.currentUser?.isTeacher == true) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              child: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
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
                            const SizedBox(width: 4),
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              child: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => _confirmDeleteLesson(lesson),
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
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
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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

  void _confirmDeleteLesson(Lesson lesson) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: Text('Permanently delete "${lesson.topic}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _firestoreService.deleteLesson(lesson.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lesson deleted'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
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
