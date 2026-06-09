import 'package:flutter/material.dart';
import '../../models/schedule_item.dart';
import '../../utils/campus_map_data.dart';

class LessonDetailSheet extends StatelessWidget {
  final ScheduleItem lesson;
  final void Function({String? locationId, String? teacherName}) onShowMap;

  const LessonDetailSheet({
    super.key,
    required this.lesson,
    required this.onShowMap,
  });

  @override
  Widget build(BuildContext context) {
    final location = findLocationByVenue(lesson.room);
    final teacherLocation = findLocationByTeacher(lesson.teacher);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            lesson.subject,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${lesson.startTime} - ${lesson.endTime}',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          _buildOption(
            context,
            icon: Icons.location_on,
            iconColor: Colors.red,
            title: 'Venue: ${lesson.room}',
            subtitle: location != null ? location.name : 'View on campus map',
            onTap: location != null
                ? () {
                    onShowMap(locationId: location.id);
                    Navigator.pop(context);
                  }
                : null,
          ),
          const SizedBox(height: 12),
          _buildOption(
            context,
            icon: Icons.person,
            iconColor: Colors.blue,
            title: 'Teacher: ${lesson.teacher}',
            subtitle: teacherLocation != null
                ? 'Office: ${teacherLocation.name}'
                : 'View on campus map',
            onTap: teacherLocation != null
                ? () {
                    onShowMap(teacherName: lesson.teacher);
                    Navigator.pop(context);
                  }
                : null,
          ),
          const SizedBox(height: 12),
          _buildOption(
            context,
            icon: Icons.alarm,
            iconColor: Colors.orange,
            title: 'Set Reminder',
            subtitle: 'Get notified before this lesson starts',
            onTap: () {
              Navigator.pop(context);
              _showReminderDialog(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showReminderDialog(BuildContext context) {
    final times = [5, 10, 15, 30, 60];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Reminder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: times.map((minutes) {
            final label = minutes >= 60
                ? '${minutes ~/ 60} hour${minutes > 60 ? 's' : ''} before'
                : '$minutes minutes before';
            return ListTile(
              title: Text(label),
              leading: const Icon(Icons.timer_outlined),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Reminder set for $label'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
