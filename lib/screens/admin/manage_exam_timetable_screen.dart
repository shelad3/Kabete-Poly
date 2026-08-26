// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/exam_timetable_entry.dart';

class ManageExamTimetableScreen extends StatefulWidget {
  const ManageExamTimetableScreen({super.key});

  @override
  State<ManageExamTimetableScreen> createState() =>
      _ManageExamTimetableScreenState();
}

class _ManageExamTimetableScreenState extends State<ManageExamTimetableScreen> {
  String? _selectedClassId;
  List<Map<String, dynamic>> _classes = [];
  bool _isLoadingClasses = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('classes')
        .get();
    setState(() {
      _classes = snapshot.docs
          .map(
            (doc) => {'id': doc.id, 'name': doc['name'] as String? ?? doc.id},
          )
          .toList();
      _isLoadingClasses = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Exam Timetables')),
      body: _isLoadingClasses
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text('No classes found'),
                  const Text('Create a class first.'),
                ],
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Select Class',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.class_),
                    ),
                    items: _classes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(c['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedClassId = v),
                  ),
                ),
                if (_selectedClassId != null)
                  Expanded(
                    child: _ExamTimetableList(classId: _selectedClassId!),
                  ),
              ],
            ),
      floatingActionButton: _selectedClassId == null
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddEntryDialog(context),
              child: const Icon(Icons.add),
            ),
    );
  }

  void _showAddEntryDialog(BuildContext context) {
    final subjectCtrl = TextEditingController();
    final teacherCtrl = TextEditingController();
    final roomCtrl = TextEditingController();
    final instructionsCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);
    String examType = 'final';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Add Exam Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: teacherCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Invigilator',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: roomCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Venue / Room',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: examType,
                  decoration: const InputDecoration(
                    labelText: 'Exam Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'cat', child: Text('CAT')),
                    DropdownMenuItem(value: 'midterm', child: Text('Mid-Term')),
                    DropdownMenuItem(value: 'final', child: Text('Final')),
                    DropdownMenuItem(
                      value: 'practical',
                      child: Text('Practical'),
                    ),
                  ],
                  onChanged: (v) => setDState(() => examType = v!),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDState(() => selectedDate = picked);
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Start'),
                        subtitle: Text(startTime.format(ctx)),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: startTime,
                          );
                          if (picked != null) {
                            setDState(() => startTime = picked);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('End'),
                        subtitle: Text(endTime.format(ctx)),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: endTime,
                          );
                          if (picked != null) {
                            setDState(() => endTime = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instructionsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Instructions (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (subjectCtrl.text.isEmpty || roomCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Subject and venue are required'),
                    ),
                  );
                  return;
                }

                final startStr =
                    '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                final endStr =
                    '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

                final entry = {
                  'classId': _selectedClassId!,
                  'subject': subjectCtrl.text.trim(),
                  'teacher': teacherCtrl.text.trim(),
                  'room': roomCtrl.text.trim(),
                  'date': Timestamp.fromDate(selectedDate),
                  'startTime': startStr,
                  'endTime': endStr,
                  'type': examType,
                  'instructions': instructionsCtrl.text.trim(),
                };

                await FirebaseFirestore.instance
                    .collection('classes')
                    .doc(_selectedClassId)
                    .collection('exam_timetable')
                    .add(entry);

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exam entry added')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamTimetableList extends StatelessWidget {
  final String classId;
  const _ExamTimetableList({required this.classId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('exam_timetable')
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('No exam entries yet. Tap + to add one.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final entry = ExamTimetableEntry.fromFirestore(docs[index]);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  entry.subject,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${entry.typeLabel} | ${entry.room} | ${entry.startTime}–${entry.endTime}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Entry'),
                        content: Text('Remove ${entry.subject} exam?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseFirestore.instance
                          .collection('classes')
                          .doc(classId)
                          .collection('exam_timetable')
                          .doc(entry.id)
                          .delete();
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
