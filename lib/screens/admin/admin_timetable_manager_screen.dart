import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/schedule_item.dart';
import '../../services/firestore_service.dart';
import '../../services/class_provider.dart';

class AdminTimetableManagerScreen extends StatefulWidget {
  const AdminTimetableManagerScreen({super.key});

  @override
  State<AdminTimetableManagerScreen> createState() => _AdminTimetableManagerScreenState();
}

class _AdminTimetableManagerScreenState extends State<AdminTimetableManagerScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _currentClassId = '';

  final Map<int, String> _weekdays = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    final cp = context.read<ClassProvider>();
    _currentClassId = cp.availableClasses.isNotEmpty ? cp.availableClasses.first : '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Manager'),
      ),
      body: _currentClassId.isEmpty
          ? const Center(child: Text('No classes available'))
          : Column(
              children: [
                _buildClassSelector(),
                const Divider(),
                Expanded(
                  child: StreamBuilder<List<ScheduleItem>>(
                    stream: _firestoreService.getDefaultScheduleStream(_currentClassId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_month_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('No official timetable entries for $_currentClassId.',
                                  style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                              const SizedBox(height: 8),
                              Text('Tap + to add the first entry.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                            ],
                          ),
                        );
                      }

                      final grouped = <int, List<ScheduleItem>>{};
                      for (var item in items) {
                        final day = item.dayOfWeek ?? 1;
                        grouped[day] = (grouped[day] ?? [])..add(item);
                      }

                      final sortedDays = grouped.keys.toList()..sort();

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: sortedDays.length,
                        itemBuilder: (context, index) {
                          final dayInt = sortedDays[index];
                          final dayItems = grouped[dayInt]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  _weekdays[dayInt] ?? 'Unknown Day',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                ),
                              ),
                              ...dayItems.map((item) => _buildScheduleCard(item)),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEntryDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Lesson'),
      ),
    );
  }

  Widget _buildClassSelector() {
    return Consumer<ClassProvider>(
      builder: (context, cp, _) {
        final classes = cp.availableClasses;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: DropdownButtonFormField<String>(
            initialValue: _currentClassId,
            decoration: const InputDecoration(
              labelText: 'Target Class',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.group),
            ),
            items: classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _currentClassId = val);
            },
          ),
        );
      },
    );
  }

  Widget _buildScheduleCard(ScheduleItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 4,
          height: double.infinity,
          color: item.color,
        ),
        title: Text('${item.startTime} - ${item.endTime} | ${item.subject}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Room: ${item.room} • Tr: ${item.teacher}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(item),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(ScheduleItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Remove ${item.subject} from $_currentClassId timetable?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.deleteScheduleItem(item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry removed.')));
      }
    }
  }

  void _showAddEntryDialog() {
    final subjectController = TextEditingController();
    final teacherController = TextEditingController();
    final roomController = TextEditingController();
    int selectedDay = DateTime.now().weekday;
    TimeOfDay? selectedStart;
    TimeOfDay? selectedEnd;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16, right: 16, top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('New Timetable Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: teacherController, decoration: const InputDecoration(labelText: 'Teacher', border: OutlineInputBorder()))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: roomController, decoration: const InputDecoration(labelText: 'Room', border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedDay,
                      decoration: const InputDecoration(labelText: 'Day of Week', border: OutlineInputBorder()),
                      items: _weekdays.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                      onChanged: (val) => setModalState(() => selectedDay = val!),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(selectedStart != null ? selectedStart!.format(context) : 'Start Time'),
                            onPressed: () async {
                              final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0));
                              if (time != null) setModalState(() => selectedStart = time);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time_filled),
                            label: Text(selectedEnd != null ? selectedEnd!.format(context) : 'End Time'),
                            onPressed: () async {
                              final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
                              if (time != null) setModalState(() => selectedEnd = time);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: () async {
                          if (subjectController.text.isEmpty || selectedStart == null || selectedEnd == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all critical fields')));
                            return;
                          }

                          String formatTime(TimeOfDay tod) {
                            final hh = tod.hour.toString().padLeft(2, '0');
                            final mm = tod.minute.toString().padLeft(2, '0');
                            return '$hh:$mm';
                          }

                          final newItem = ScheduleItem(
                            id: '',
                            classId: _currentClassId,
                            subject: subjectController.text.trim(),
                            teacher: teacherController.text.trim().isEmpty ? 'TBA' : teacherController.text.trim(),
                            room: roomController.text.trim().isEmpty ? 'TBA' : roomController.text.trim(),
                            startTime: formatTime(selectedStart!),
                            endTime: formatTime(selectedEnd!),
                            color: Colors.blueGrey,
                            description: 'Official Timetable',
                            date: DateTime.now(),
                            isDefault: true,
                            dayOfWeek: selectedDay,
                          );

                          await _firestoreService.addScheduleItem(newItem);

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved successfully!')));
                          }
                        },
                        child: const Text('Save Entry to Cloud'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
