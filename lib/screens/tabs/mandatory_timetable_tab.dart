import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/timetable_data.dart';
import '../../services/auth_provider.dart';
import '../../services/notification_service.dart';

class MandatoryTimetableTab extends StatefulWidget {
  const MandatoryTimetableTab({super.key});

  @override
  State<MandatoryTimetableTab> createState() => _MandatoryTimetableTabState();
}

class _MandatoryTimetableTabState extends State<MandatoryTimetableTab> {
  String _selectedCohort = 'EET 600 M24';
  final NotificationService _notificationService = NotificationService();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isStudent = user != null && (user.role == 'Student' || user.role == 'Leader');
    final hasEnrolledClass = user != null && user.enrolledClasses.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-select user's enrolled class if available
    if (hasEnrolledClass) {
      final firstClass = user.enrolledClasses.first;
      if (TimetableData.cohorts.containsKey(firstClass) && _selectedCohort != firstClass) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedCohort = firstClass);
        });
      }
    }

    final weekSchedule = TimetableData.getTimetableForCohort(_selectedCohort);
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isStudent, hasEnrolledClass, isDark),
          const SizedBox(height: 24),
          ...days.map((day) {
            final lessons = weekSchedule[day] ?? [];
            if (lessons.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 4),
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.blueGrey,
                    ),
                  ),
                ),
                ...lessons.map((lesson) => _buildMandatoryCard(lesson, day, isDark)),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isStudent, bool hasEnrolledClass, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Department Timetable',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: isDark ? Colors.white54 : Colors.blueGrey),
              ),
              Text(
                'Official Classes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : null),
              ),
            ],
          ),
          isStudent
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _selectedCohort,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                            ),
                          ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCohort,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                      items: TimetableData.cohorts.keys.map((String cohort) {
                        return DropdownMenuItem<String>(
                          value: cohort,
                          child: Text(cohort),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedCohort = newValue);
                        }
                      },
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildMandatoryCard(Map<String, dynamic> lesson, String dayString, bool isDark) {
    final Color stripColor = Color(lesson['color'] as int);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : Colors.white,
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
              Container(
                width: 6,
                color: stripColor,
              ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: stripColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lesson['time'],
                              style: TextStyle(color: stripColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                          InkWell(
                            onTap: () => _scheduleAlert(lesson, dayString),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.1),
                              ),
                              child: Icon(Icons.notifications_none, size: 18, color: isDark ? Colors.white54 : Colors.blueGrey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        lesson['unit'],
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : null),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(lesson['room'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(width: 16),
                          const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              lesson['lecturer'],
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
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
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final int dayIndex = days.indexOf(dayString) + 1;
    final uniqueId = lesson['unit'].hashCode.abs() % 10000;

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
        content: Text('Reminders Set! You will be alerted at 08:00 AM and 30m before ${lesson['unit']}.'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
