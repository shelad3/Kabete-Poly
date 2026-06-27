import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/class_provider.dart';
import '../models/lesson.dart';
import '../models/schedule_item.dart';
import '../widgets/app_drawer.dart';
import '../widgets/shimmer_loading.dart';
import 'notification_screen.dart';
import 'tabs/mandatory_timetable_tab.dart';
import 'schedule/campus_map_widget.dart';
import 'schedule/lesson_detail_sheet.dart';
import '../utils/campus_map_data.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  String? _highlightId;
  String? _highlightLabel;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void switchToMapTab({String? highlightId, String? highlightLabel}) {
    setState(() {
      _highlightId = highlightId;
      _highlightLabel = highlightLabel;
    });
    _tabController.animateTo(2);
  }

  void _showLessonDetail(ScheduleItem lesson) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LessonDetailSheet(
        lesson: lesson,
        onShowMap: ({locationId, teacherName}) {
          setState(() {
            if (locationId != null) {
              _highlightId = locationId;
              _highlightLabel = lesson.room;
            } else if (teacherName != null) {
              final loc = findLocationByTeacher(teacherName);
              _highlightId = loc?.id;
              _highlightLabel = '$teacherName\'s Office';
            }
          });
          _tabController.animateTo(2);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('My Timetable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Mandatory', icon: Icon(Icons.assignment_turned_in)),
            Tab(text: 'Target Timeline', icon: Icon(Icons.timeline)),
            Tab(text: 'Map', icon: Icon(Icons.map)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const MandatoryTimetableTab(),
          _buildTargetTimelineTab(),
          _buildMapTab(),
        ],
      ),
    );
  }

  Widget _buildMapTab() {
    return CampusMapWidget(
      highlightId: _highlightId,
      highlightLabel: _highlightLabel,
    );
  }

  Widget _buildTargetTimelineTab() {
    return Consumer<ClassProvider>(
      builder: (context, classProvider, _) {
        final classId = classProvider.currentClass;
        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: TabBar(
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelColor: Colors.grey,
                  tabs: const [
                    Tab(text: 'Past Lessons'),
                    Tab(text: 'Upcoming Lessons'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildPastLessonsTab(classId),
                    _buildUpcomingLessonsTab(classId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPastLessonsTab(String classId) {
    return StreamBuilder<List<Lesson>>(
      stream: _firestoreService.getLessonsStream(classId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerScheduleList();
        }
        final lessons = snapshot.data ?? [];
        if (lessons.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No completed lessons yet.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: lessons.length,
          itemBuilder: (_, i) {
            final lesson = lessons[i];
            final isPractical = lesson.report.isNotEmpty || lesson.practicalPictures.isNotEmpty;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPractical ? Colors.purple.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  child: Icon(
                    isPractical ? Icons.science : Icons.auto_stories,
                    color: isPractical ? Colors.purple : Colors.orange,
                  ),
                ),
                title: Text(lesson.topic, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.subtopic, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('${lesson.teacher} • ${_formatDate(lesson.date)}${isPractical ? ' • Practical' : ''}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
                isThreeLine: false,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUpcomingLessonsTab(String classId) {
    return StreamBuilder<List<ScheduleItem>>(
      stream: _firestoreService.getScheduleTimelineStream(classId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ShimmerScheduleList();
        }
        final allItems = snapshot.data ?? [];
        final today = DateTime.now();
        final startOfToday = DateTime(today.year, today.month, today.day);

        final upcoming = allItems.where((item) {
          if (item.isDefault) {
            return item.dayOfWeek != null && item.dayOfWeek! >= today.weekday;
          }
          return item.date.isAfter(startOfToday.subtract(const Duration(seconds: 1)));
        }).toList();

        upcoming.sort((a, b) => a.date.compareTo(b.date));

        final practicals = upcoming.where((i) => i.description.contains('Practical')).toList();
        final theory = upcoming.where((i) => !i.description.contains('Practical')).toList();

        if (upcoming.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_month_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('No upcoming lessons.', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (practicals.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.science, size: 18, color: Colors.purple),
                    const SizedBox(width: 6),
                    Text('Upcoming Practicals (${practicals.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.purple)),
                  ],
                ),
              ),
              ...practicals.map(_buildCompactScheduleCard),
              const SizedBox(height: 12),
            ],
            if (theory.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_stories, size: 18, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text('Upcoming Theory (${theory.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orange)),
                  ],
                ),
              ),
              ...theory.map(_buildCompactScheduleCard),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCompactScheduleCard(ScheduleItem item) {
    final isPractical = item.description.contains('Practical');
    final color = isPractical ? Colors.purple : Colors.orange;
    final dateStr = item.isDefault
        ? 'Every ${['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][item.dayOfWeek ?? 0]}'
        : _formatDate(item.date);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(isPractical ? Icons.science : Icons.auto_stories, color: color, size: 20),
        ),
        title: Text(item.subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('$dateStr • ${item.startTime} - ${item.endTime} • ${item.teacher}',
            style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => _showLessonDetail(item),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}
