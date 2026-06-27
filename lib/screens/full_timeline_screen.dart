import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/lesson.dart';
import '../models/schedule_item.dart';
import '../models/feed_item.dart';
import '../services/firestore_service.dart';
import '../services/quiz_service.dart';
import '../services/class_provider.dart';
import '../models/quiz.dart';

class FullTimelineScreen extends StatefulWidget {
  const FullTimelineScreen({super.key});

  @override
  State<FullTimelineScreen> createState() => _FullTimelineScreenState();
}

class _FullTimelineScreenState extends State<FullTimelineScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final QuizService _quizService = QuizService();
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Full Timeline'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Theory'),
            Tab(text: 'Practical'),
            Tab(text: 'Quizzes'),
          ],
        ),
      ),
      body: Consumer<ClassProvider>(
        builder: (context, classProvider, _) {
          final targetClass = classProvider.currentClass;
          return TabBarView(
            controller: _tabCtrl,
            children: [
              _buildAllTab(targetClass),
              _buildTheoryTab(targetClass),
              _buildPracticalTab(targetClass),
              _buildQuizzesTab(targetClass),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAllTab(String targetClass) {
    return _buildCombinedFeed(targetClass, null);
  }

  Widget _buildTheoryTab(String targetClass) {
    return _buildCombinedFeed(targetClass, 'theory');
  }

  Widget _buildPracticalTab(String targetClass) {
    return _buildCombinedFeed(targetClass, 'practical');
  }

  Widget _buildCombinedFeed(String targetClass, String? filter) {
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
              return const Center(child: CircularProgressIndicator());
            }

            final now = DateTime.now();
            final lessons = lessonSnap.data ?? [];

            List<FeedItem> feed = [];
            for (final l in lessons) {
              if (filter == null) {
                feed.add(FeedItem.lesson(l));
              } else if (filter == 'theory' && l.report.isEmpty) {
                feed.add(FeedItem.lesson(l));
              } else if (filter == 'practical' && l.report.isNotEmpty) {
                feed.add(FeedItem.lesson(l));
              }
            }

            if (filter == null || filter == 'theory') {
              final schedules = scheduleSnap.data ?? [];
              for (final s in schedules) {
                if (s.date.isBefore(now) && !s.description.contains('Practical')) {
                  feed.add(FeedItem.schedule(s));
                }
              }
            }
            if (filter == null || filter == 'practical') {
              final schedules = scheduleSnap.data ?? [];
              for (final s in schedules) {
                if (s.date.isBefore(now) && s.description.contains('Practical')) {
                  feed.add(FeedItem.schedule(s));
                }
              }
            }

            feed.sort((a, b) => b.date.compareTo(a.date));

            if (feed.isEmpty) {
              return const Center(child: Text('No items yet.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: feed.length,
              itemBuilder: (context, index) {
                final item = feed[index];
                if (item.type == 'lesson') {
                  return _buildLessonItem(item.lesson!);
                }
                return _buildScheduleItem(item.schedule!);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildQuizzesTab(String targetClass) {
    return StreamBuilder<List<Quiz>>(
      stream: _quizService.getQuizzesStream(targetClass),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final quizzes = snapshot.data ?? [];
        if (quizzes.isEmpty) {
          return const Center(child: Text('No quizzes yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: quizzes.length,
          itemBuilder: (_, i) {
            final q = quizzes[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.teal.withValues(alpha: 0.1),
                  child: const Icon(Icons.quiz, color: Colors.teal, size: 20),
                ),
                title: Text(q.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(DateFormat('MMM dd, yyyy').format(q.createdAt),
                    style: const TextStyle(fontSize: 12)),
                trailing: Text('${q.durationMinutes} min',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLessonItem(Lesson lesson) {
    final isPractical = lesson.report.isNotEmpty;
    final color = isPractical ? Colors.purple : Colors.orange;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(isPractical ? Icons.science : Icons.auto_stories,
              color: color, size: 20),
        ),
        title: Text(lesson.topic, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${lesson.subtopic} • ${DateFormat('MMM dd, yyyy').format(lesson.date)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildScheduleItem(ScheduleItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: item.color.withValues(alpha: 0.1),
          child: Icon(
            item.description.contains('Practical') ? Icons.science : Icons.book,
            color: item.color,
            size: 20,
          ),
        ),
        title: Text(item.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${item.startTime}-${item.endTime} • ${item.room} • ${DateFormat('MMM dd, yyyy').format(item.date)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      ),
    );
  }
}
