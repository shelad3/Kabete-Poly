// SPDX-License-Identifier: AGPL-3.0-or-Later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_provider.dart';
import '../../services/class_provider.dart';
import '../../services/notification_service.dart';
import '../admin/manage_timetable_screen.dart';

class MandatoryTimetableTab extends StatefulWidget {
  const MandatoryTimetableTab({super.key});

  @override
  State<MandatoryTimetableTab> createState() => _MandatoryTimetableTabState();
}

class _MandatoryTimetableTabState extends State<MandatoryTimetableTab> {
  String _selectedCohort = 'EET 600 M24';
  final NotificationService _notificationService = NotificationService();
  bool _initialized = false;
  bool _remindersScheduled = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _dayKeys = {};
  bool _didAutoScrollToToday = false;
  String _timetableDisplayMode = 'classic';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && user.enrolledClasses.isNotEmpty) {
      final preferred = _preferredClass(user.enrolledClasses);
      if (preferred != null) _selectedCohort = preferred;
    }
    _notificationService.loadAutoReminderPref();
    _initialized = true;
    _loadTimetablePrefs();
  }

  Future<void> _loadTimetablePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _timetableDisplayMode =
        prefs.getString('timetable_display_mode') ?? 'classic';
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Pick the first enrolled class the user actually owns, skipping the
  /// pseudo-cohort ('Global / General Assembly') that admins/officials carry
  /// in addition to their real class — otherwise the timetable would always
  /// auto-select the pseudo-cohort instead of the class they care about.
  static String? _preferredClass(List<String> enrolledClasses) {
    final normalized = enrolledClasses.map(_normalizeClassId).toList();
    final real = normalized
        .where((c) => c != 'Global / General Assembly')
        .toList();
    if (real.isNotEmpty) return real.first;
    return normalized.isNotEmpty ? normalized.first : null;
  }

  /// Normalize class ID: replace slashes/dashes with spaces to match
  /// Firestore class document IDs (e.g. "ICT/600/M26" → "ICT 600 M26").
  static String _normalizeClassId(String id) {
    return id
        .replaceAll(RegExp(r'[/\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isStudent =
        user != null && (user.role == 'Student' || user.role == 'Leader');
    final isTeacher = user != null && (user.isTeacher || user.isLeader);
    final hasEnrolledClass = user != null && user.enrolledClasses.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final firestoreRef = FirebaseFirestore.instance
        .collection('classes')
        .doc(_selectedCohort)
        .collection('timetable');

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isStudent, hasEnrolledClass, isTeacher, isDark),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: firestoreRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading timetable',
                    style: TextStyle(color: Colors.red[400]),
                  ),
                );
              }

              final entriesByDay = <String, List<Map<String, dynamic>>>{};
              final allLessons = <Map<String, dynamic>>[];
              if (snapshot.hasData) {
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final day = data['day'] as String? ?? '';
                  entriesByDay.putIfAbsent(day, () => []).add(data);
                  allLessons.add(data);
                }
              }

              // Auto-schedule reminders when data first loads
              if (snapshot.hasData &&
                  snapshot.data!.docs.isNotEmpty &&
                  !_remindersScheduled &&
                  _notificationService.autoRemindersEnabled) {
                _remindersScheduled = true;
                _autoScheduleReminders(allLessons);
              }

              final dayOrder = {
                'Monday': 0,
                'Tuesday': 1,
                'Wednesday': 2,
                'Thursday': 3,
                'Friday': 4,
              };
              final sortedDays = entriesByDay.keys.toList()
                ..sort(
                  (a, b) =>
                      (dayOrder[a] ?? 99).compareTo(dayOrder[b] ?? 99),
                );

              if (sortedDays.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No timetable entries yet',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Entries will appear here once uploaded to the database.',
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Open on today's section once data first arrives (Settings >
              // Timetable Display > Start on Today).
              if (snapshot.hasData &&
                  snapshot.data!.docs.isNotEmpty &&
                  !_didAutoScrollToToday) {
                _didAutoScrollToToday = true;
                _maybeScrollToToday();
              }

              // Week grid mode: same data, compact table (time rows x day columns,
              // today's column highlighted).
              if (_timetableDisplayMode == 'grid') {
                return _buildWeekGrid(sortedDays, entriesByDay, isDark);
              }

              // Today-first mode: move today's section to the top.
              final displayDays = _timetableDisplayMode == 'today_first'
                  ? _reorderTodayFirst(sortedDays)
                  : sortedDays;

              return Column(
                children: displayDays.map((day) {
                  final entries = entriesByDay[day] ?? [];
                  entries.sort((a, b) {
                    final ta = parseLessonStartTime(
                      a['time'] as String? ?? '',
                    );
                    final tb = parseLessonStartTime(
                      b['time'] as String? ?? '',
                    );
                    if (ta == null && tb == null) return 0;
                    if (ta == null) return 1;
                    if (tb == null) return -1;
                    return (ta.$1 * 60 + ta.$2).compareTo(tb.$1 * 60 + tb.$2);
                  });
                  return KeyedSubtree(
                    key: _dayKeys[day] ??= GlobalKey(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: 12,
                            left: 4,
                            top: 12,
                          ),
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white70
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        ...entries.map(
                          (lesson) =>
                              _buildMandatoryCard(lesson, day, isDark),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    bool isStudent,
    bool hasEnrolledClass,
    bool isTeacher,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2A3E)
            : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white10
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Department Timetable',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: isDark
                      ? Colors.white54
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              Text(
                'Official Classes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : null,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Auto-reminder toggle
              if (isStudent && hasEnrolledClass)
                _buildReminderToggle(isDark),
              if (isTeacher)
                IconButton(
                  icon: Icon(
                    Icons.edit_calendar,
                    color: isDark
                        ? Colors.white70
                        : Theme.of(context).colorScheme.primary,
                  ),
                  tooltip: 'Manage Timetable',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageTimetableScreen(
                          className: _selectedCohort,
                        ),
                      ),
                    );
                  },
                ),
              // Admins/officials need the dropdown too, otherwise their
              // timetable is locked to the auto-selected (pseudo) cohort.
              if (hasEnrolledClass)
                _buildClassDropdown(isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderToggle(bool isDark) {
    return Tooltip(
      message: _notificationService.autoRemindersEnabled
          ? 'Auto-reminders ON (20 min before each class)'
          : 'Auto-reminders OFF',
      child: Switch(
        value: _notificationService.autoRemindersEnabled,
        onChanged: (val) async {
          await _notificationService.setAutoRemindersEnabled(val);
          if (val && mounted) {
            // Re-trigger scheduling on next stream event
            _remindersScheduled = false;
            setState(() {});
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  val
                      ? 'Auto-reminders enabled — you\'ll be notified 20 min before each class'
                      : 'Auto-reminders disabled',
                ),
                backgroundColor: val ? Colors.green : Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        activeThumbColor: Colors.green,
      ),
    );
  }

  Widget _buildClassDropdown(bool isDark) {
    return Consumer<ClassProvider>(
      builder: (context, classProvider, _) {
        final items = classProvider.availableClasses
            .where((c) => c != 'Global / General Assembly')
            .toList();
        if (!items.contains(_selectedCohort)) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: _selectedCohort,
            underline: const SizedBox.shrink(),
            isDense: true,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black87,
            ),
            items: items
                .map(
                  (c) => DropdownMenuItem(value: c, child: Text(c)),
                )
                .toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedCohort = newValue;
                  _remindersScheduled = false;
                });
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _maybeScrollToToday() async {
    final weekday = DateTime.now().weekday;
    if (weekday < 1 || weekday > 5) return;
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ];
    final today = dayNames[weekday - 1];
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('timetable_start_on_today') ?? true)) return;
    if (!mounted) return;
    // Wait a frame so the day sections are laid out, then glide to today.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _dayKeys[today]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  List<String> _reorderTodayFirst(List<String> sortedDays) {
    final weekday = DateTime.now().weekday;
    if (weekday < 1 || weekday > 5) return sortedDays;
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ];
    final today = dayNames[weekday - 1];
    if (!sortedDays.contains(today)) return sortedDays;
    return [today, ...sortedDays.where((d) => d != today)];
  }

  Widget _buildWeekGrid(
    List<String> sortedDays,
    Map<String, List<Map<String, dynamic>>> entriesByDay,
    bool isDark,
  ) {
    final weekday = DateTime.now().weekday;
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ];
    final today = (weekday >= 1 && weekday <= 5)
        ? dayNames[weekday - 1]
        : null;

    final timeSlots = <String>{};
    for (final day in sortedDays) {
      for (final lesson in entriesByDay[day] ?? []) {
        final t = lesson['time'] as String? ?? '';
        if (t.isNotEmpty) timeSlots.add(t);
      }
    }
    final sortedTimes = timeSlots.toList()
      ..sort((a, b) {
        final ta = parseLessonStartTime(a);
        final tb = parseLessonStartTime(b);
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return (ta.$1 * 60 + ta.$2).compareTo(tb.$1 * 60 + tb.$2);
      });

    final primary = Theme.of(context).colorScheme.primary;

    Widget headerCell(String label, bool isToday) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        color: isToday ? primary : null,
        child: Text(
          isToday ? label.substring(0, 3).toUpperCase() : label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isToday
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 0.5,
        ),
        defaultColumnWidth: const FixedColumnWidth(92),
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF15152A) : const Color(0xFFE8EEF7),
            ),
            children: [
              headerCell('Time', false),
              ...sortedDays.map((day) => headerCell(day, day == today)),
            ],
          ),
          ...sortedTimes.map((time) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
                ...sortedDays.map((day) {
                  final match = (entriesByDay[day] ?? []).firstWhere(
                    (l) => (l['time'] as String? ?? '') == time,
                    orElse: () => const {},
                  );
                  if (match.isEmpty) {
                    return Container(
                      height: 54,
                      color: day == today
                          ? primary.withValues(alpha: 0.08)
                          : null,
                    );
                  }
                  final Color strip = Color(match['color'] as int);
                  final unit = match['unit'] as String? ?? '';
                  final lecturer = match['lecturer'] as String? ?? '';
                  return Container(
                    height: 54,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: day == today
                          ? strip.withValues(alpha: isDark ? 0.25 : 0.2)
                          : strip.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : strip,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (lecturer.isNotEmpty)
                          Text(
                            lecturer,
                            style: const TextStyle(fontSize: 9),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _autoScheduleReminders(List<Map<String, dynamic>> lessons) async {
    try {
      final count = await _notificationService.autoScheduleClassReminders(
        className: _selectedCohort,
        lessons: lessons,
      );
      if (mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Auto-reminders set: $count notifications scheduled (20 min before each class)',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Auto-reminder scheduling failed for $_selectedCohort: $e');
    }
  }

  Widget _buildMandatoryCard(
    Map<String, dynamic> lesson,
    String dayString,
    bool isDark,
  ) {
    final Color stripColor = Color(lesson['color'] as int);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2A3E)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: stripColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: stripColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${lesson['time']} - ${lesson['endTime']}',
                                  style: TextStyle(
                                    color: stripColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _scheduleAlert(lesson, dayString),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.white10
                                    : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.1),
                              ),
                              child: Icon(
                                Icons.notifications_none,
                                size: 18,
                                color: isDark
                                    ? Colors.white54
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        lesson['unit'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lesson['room'],
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lesson['lecturer'],
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scheduleAlert(Map<String, dynamic> lesson, String dayString) {
    final timeStr = lesson['time'] as String;
    final cleanTime = timeStr.replaceAll(RegExp(r'[^0-9]'), '');
    int hour = 8;
    int minute = 0;
    if (cleanTime.length >= 4) {
      final startChunk = cleanTime.substring(0, 4);
      hour = int.tryParse(startChunk.substring(0, 2)) ?? 8;
      minute = int.tryParse(startChunk.substring(2, 4)) ?? 0;
    }
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final int dayIndex = days.indexOf(dayString) + 1;
    final uniqueId = lesson['unit'].hashCode.abs() % 10000;

    _notificationService.requestPermissions();
    _notificationService.scheduleClassReminder(
      id: uniqueId,
      className: lesson['unit'],
      room: lesson['room'],
      dayOfWeek: dayIndex,
      hour: hour,
      minute: minute,
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Reminder set! You\'ll be notified 20 min before ${lesson['unit']}.',
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
