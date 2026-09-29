// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/class_provider.dart';
import '../services/auth_provider.dart';
import '../providers/feature_flag_provider.dart';
import '../models/lesson.dart';
import '../models/schedule_item.dart';
import '../widgets/app_drawer.dart';
import '../widgets/shimmer_loading.dart';
import 'notification_screen.dart';
import 'tabs/mandatory_timetable_tab.dart';
import 'tabs/exam_timetable_tab.dart';
import 'schedule/campus_map_widget.dart';
import 'schedule/lesson_detail_sheet.dart';
import '../utils/campus_map_data.dart';

enum _ScheduleTabKind { mandatory, timeline, exam, map }

class _ScheduleTabSpec {
  const _ScheduleTabSpec(this.flag, this.kind, this.label, this.icon);
  final String flag;
  final _ScheduleTabKind kind;
  final String label;
  final IconData icon;
}

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flags = context.watch<FeatureFlagProvider>();
    final role = context.watch<AuthProvider>().currentUser?.role;
    final specs = <_ScheduleTabSpec>[
      const _ScheduleTabSpec(
        'timetable',
        _ScheduleTabKind.mandatory,
        'Mandatory',
        Icons.assignment_turned_in,
      ),
      if (flags.isEnabledFor('timeline', role))
        const _ScheduleTabSpec(
          'timeline',
          _ScheduleTabKind.timeline,
          'Target Timeline',
          Icons.timeline,
        ),
      if (flags.isEnabledFor('exam_timetable', role))
        const _ScheduleTabSpec(
          'exam_timetable',
          _ScheduleTabKind.exam,
          'Exams',
          Icons.school,
        ),
      if (flags.isEnabledFor('campus_map', role))
        const _ScheduleTabSpec(
          'campus_map',
          _ScheduleTabKind.map,
          'Map',
          Icons.map,
        ),
    ];
    return _GatedScheduleTabs(
      key: ValueKey(specs.map((s) => s.flag).join('|')),
      specs: specs,
    );
  }
}

class _GatedScheduleTabs extends StatefulWidget {
  const _GatedScheduleTabs({super.key, required this.specs});

  final List<_ScheduleTabSpec> specs;

  @override
  State<_GatedScheduleTabs> createState() => _GatedScheduleTabsState();
}

class _GatedScheduleTabsState extends State<_GatedScheduleTabs>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late List<_ScheduleTabSpec> _specs;

  String? _highlightId;
  String? _highlightLabel;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _specs = widget.specs.isEmpty
        ? const [
            _ScheduleTabSpec(
              'timetable',
              _ScheduleTabKind.mandatory,
              'Mandatory',
              Icons.assignment_turned_in,
            ),
          ]
        : widget.specs;
    _tabController = TabController(length: _specs.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _GatedScheduleTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.specs.isEmpty
        ? const [
            _ScheduleTabSpec(
              'timetable',
              _ScheduleTabKind.mandatory,
              'Mandatory',
              Icons.assignment_turned_in,
            ),
          ]
        : widget.specs;
    final flagsChanged =
        next.length != _specs.length ||
        !List.generate(
          _specs.length,
          (i) => i < next.length && _specs[i].flag == next[i].flag,
          growable: false,
        ).every((same) => same);
    if (flagsChanged) {
      _specs = next;
      _tabController.dispose();
      _tabController = TabController(length: _specs.length, vsync: this);
      if (_tabController.index >= _specs.length) {
        _tabController.index = _specs.length - 1;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _mapIndex() => _specs.indexWhere((s) => s.kind == _ScheduleTabKind.map);

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
          final mapIdx = _mapIndex();
          if (mapIdx < 0) return;
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
          _tabController.animateTo(mapIdx);
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
          tabs: [
            for (final spec in _specs)
              Tab(text: spec.label, icon: Icon(spec.icon)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final spec in _specs)
            switch (spec.kind) {
              _ScheduleTabKind.mandatory => const MandatoryTimetableTab(),
              _ScheduleTabKind.timeline => _buildTargetTimelineTab(),
              _ScheduleTabKind.exam => const ExamTimetableTab(),
              _ScheduleTabKind.map => _buildMapTab(),
            },
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
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_stories_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'No completed lessons yet.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: lessons.length,
          itemBuilder: (_, i) {
            final lesson = lessons[i];
            final isPractical =
                lesson.report.isNotEmpty || lesson.practicalPictures.isNotEmpty;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPractical
                      ? Colors.purple.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  child: Icon(
                    isPractical ? Icons.science : Icons.auto_stories,
                    color: isPractical ? Colors.purple : Colors.orange,
                  ),
                ),
                title: Text(
                  lesson.topic,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.subtopic, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      '${lesson.teacher} • ${_formatDate(lesson.date)}${isPractical ? ' • Practical' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
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
          return item.date.isAfter(
            startOfToday.subtract(const Duration(seconds: 1)),
          );
        }).toList();

        upcoming.sort((a, b) => a.date.compareTo(b.date));

        final practicals = upcoming
            .where((i) => i.description.contains('Practical'))
            .toList();
        final theory = upcoming
            .where((i) => !i.description.contains('Practical'))
            .toList();

        if (upcoming.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'No upcoming lessons.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
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
                    const Icon(Icons.science, size: 18, color: Colors.purple),
                    const SizedBox(width: 6),
                    Text(
                      'Upcoming Practicals (${practicals.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.purple,
                      ),
                    ),
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
                    const Icon(Icons.auto_stories, size: 18, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text(
                      'Upcoming Theory (${theory.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.orange,
                      ),
                    ),
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
          child: Icon(
            isPractical ? Icons.science : Icons.auto_stories,
            color: color,
            size: 20,
          ),
        ),
        title: Text(
          item.subject,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '$dateStr • ${item.startTime} - ${item.endTime} • ${item.teacher}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: () => _showLessonDetail(item),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}