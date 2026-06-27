import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/schedule_item.dart';
import '../services/firestore_service.dart';
import '../services/class_provider.dart';

class IncomingLessonsScreen extends StatefulWidget {
  const IncomingLessonsScreen({super.key});

  @override
  State<IncomingLessonsScreen> createState() => _IncomingLessonsScreenState();
}

class _IncomingLessonsScreenState extends State<IncomingLessonsScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
        title: const Text('Incoming Lessons'),
        bottom: TabBar(
          controller: _tabCtrl,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Practical'),
            Tab(text: 'Theory'),
          ],
        ),
      ),
      body: Consumer<ClassProvider>(
        builder: (context, classProvider, _) {
          return StreamBuilder<List<ScheduleItem>>(
            stream: _firestoreService.getScheduleTimelineStream(classProvider.currentClass),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
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

              return TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildLessonList(upcoming.where((i) => i.description.contains('Practical')).toList(), Colors.purple),
                  _buildLessonList(upcoming.where((i) => !i.description.contains('Practical')).toList(), Colors.orange),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLessonList(List<ScheduleItem> items, Color color) {
    if (items.isEmpty) {
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
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        final dateStr = item.isDefault
            ? 'Every ${['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][item.dayOfWeek ?? 0]}'
            : DateFormat('MMM dd, yyyy').format(item.date);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(
                item.description.contains('Practical') ? Icons.science : Icons.auto_stories,
                color: color,
              ),
            ),
            title: Text(item.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('$dateStr • ${item.startTime} - ${item.endTime} • ${item.teacher}',
                style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, size: 18),
          ),
        );
      },
    );
  }
}
