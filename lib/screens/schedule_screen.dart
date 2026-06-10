import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/class_provider.dart';
import '../models/schedule_item.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../widgets/app_drawer.dart';
import '../widgets/shimmer_loading.dart';
import 'notification_screen.dart';
import 'tabs/mandatory_timetable_tab.dart';
import 'quiz/quiz_list_screen.dart';
import 'schedule/campus_map_widget.dart';
import 'schedule/lesson_detail_sheet.dart';
import '../utils/campus_map_data.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with TickerProviderStateMixin {
  late Timer _timer;
  DateTime _now = DateTime.now();
  late TabController _tabController;

  String? _highlightId;
  String? _highlightLabel;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
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
                MaterialPageRoute(builder: (_) => NotificationScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Mandatory", icon: Icon(Icons.assignment_turned_in)),
            Tab(text: "Target Timeline", icon: Icon(Icons.timeline)),
            Tab(text: "Map", icon: Icon(Icons.map)),
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
        return StreamBuilder<List<ScheduleItem>>(
          stream: _firestoreService.getScheduleStream(classProvider.currentClass, _now),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading schedule.'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ShimmerScheduleList();
            }

            final schedule = snapshot.data ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDayHeader(schedule.length),
                  const SizedBox(height: 24),
                  if (schedule.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('No classes scheduled for today.')),
                    )
                  else ...[
                    if (schedule.any((i) => !i.isDefault)) ...[
                       const Row(
                         children: [
                           Icon(Icons.bolt, color: Colors.orange),
                           SizedBox(width: 8),
                           Text('Live Adjustments & Practicals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                         ],
                       ),
                       const SizedBox(height: 12),
                       ...schedule.where((i) => !i.isDefault).map((item) => _buildScheduleCard(item)),
                       const Divider(height: 32, thickness: 2),
                    ],
                    
                    if (schedule.any((i) => i.isDefault)) ...[
                       const Row(
                         children: [
                           Icon(Icons.verified, color: Colors.blueGrey),
                           SizedBox(width: 8),
                           Text('Official School Timetable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                         ],
                       ),
                       const SizedBox(height: 12),
                       ...schedule.where((i) => i.isDefault).map((item) => _buildScheduleCard(item)),
                    ],
                  ],
                  const SizedBox(height: 24),
                  _buildExtraFeatures(),
                ],
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildDayHeader(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Timeline', 
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text('$count timeline blocks scheduled', style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildScheduleCard(ScheduleItem item) {
    final progress = item.getProgress(_now);
    final isCurrent = progress > 0 && progress < 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showLessonDetail(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isCurrent ? item.color.withValues(alpha: 0.1) : (isDark ? const Color(0xFF2A2A3E) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: isCurrent ? Border.all(color: item.color, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${item.startTime} - ${item.endTime}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.red, size: 10),
                          SizedBox(width: 6),
                          Text(
                            'LIVE NOW',
                            style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                item.subject,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(item.room, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 16),
                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(item.teacher, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              if (item.attachmentUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Attachments:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 6),
                ...List.generate(item.attachmentUrls.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () async {
                        final uri = Uri.parse(item.attachmentUrls[i]);
                        final messenger = ScaffoldMessenger.of(context);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          messenger.showSnackBar(const SnackBar(content: Text('Could not open the attachment.')));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.download, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                i < item.attachmentNames.length ? item.attachmentNames[i] : 'Document ${i + 1}',
                                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
              if (isCurrent) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lesson Progress', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                    Text('${(progress * 100).toInt()}%', style: TextStyle(color: item.color, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: item.color.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(item.color),
                    minHeight: 8,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExtraFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildQuickAction(Icons.assignment_outlined, 'Deadlines', Colors.orange, () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizListScreen()));
            }),
            _buildQuickAction(Icons.school_outlined, 'Exams', Colors.red, () {
              _showComingSoon(context, 'Exam schedule coming soon.');
            }),
            _buildQuickAction(Icons.check_circle_outline, 'Attendance', Colors.green, () {
              _showComingSoon(context, 'Attendance tracking coming soon.');
            }),
            _buildQuickAction(Icons.volume_off_outlined, 'Quiet Mode', Colors.blueGrey, () {
              _showComingSoon(context, 'Quiet mode coming soon.');
            }),
          ],
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
