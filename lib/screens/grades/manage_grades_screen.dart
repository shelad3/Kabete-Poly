import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_provider.dart';
import '../../services/grade_service.dart';
import '../../models/grade_record.dart';

class ManageGradesScreen extends StatefulWidget {
  final String classId;
  const ManageGradesScreen({super.key, required this.classId});

  @override
  State<ManageGradesScreen> createState() => _ManageGradesScreenState();
}

class _ManageGradesScreenState extends State<ManageGradesScreen> {
  final GradeService _service = GradeService();
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showGradeEditor(GradeRecord? existing, String studentId, String studentName) {
    final subjectCtrl = TextEditingController(text: existing?.subjectName ?? '');
    final termCtrl = TextEditingController(text: existing?.term ?? 'Term 1');
    final yearCtrl = TextEditingController(text: existing?.academicYear ?? '2026');
    final commentCtrl = TextEditingController(text: existing?.comments ?? '');
    final formKey = GlobalKey<FormState>();

    // Dynamic assessment entries
    final assessmentKeys = <String>[];
    final scoreCtrls = <String, TextEditingController>{};
    final maxCtrls = <String, TextEditingController>{};

    if (existing != null) {
      existing.assessments.forEach((key, entry) {
        assessmentKeys.add(key);
        scoreCtrls[key] = TextEditingController(text: entry.score.toStringAsFixed(0));
        maxCtrls[key] = TextEditingController(text: entry.max.toStringAsFixed(0));
      });
    } else {
      assessmentKeys.addAll(['cat1', 'cat2', 'exam']);
      scoreCtrls['cat1'] = TextEditingController();
      maxCtrls['cat1'] = TextEditingController(text: '30');
      scoreCtrls['cat2'] = TextEditingController();
      maxCtrls['cat2'] = TextEditingController(text: '30');
      scoreCtrls['exam'] = TextEditingController();
      maxCtrls['exam'] = TextEditingController(text: '100');
    }

    void rebuild() => setState(() {});

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          return AlertDialog(
            title: Text(existing != null ? 'Edit Grade' : 'Add Grade'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student: $studentName', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: subjectCtrl,
                      decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    ...assessmentKeys.map((key) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: TextFormField(
                                decoration: InputDecoration(
                                  labelText: 'Name',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                initialValue: key,
                                enabled: false,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextFormField(
                                controller: scoreCtrls[key],
                                decoration: const InputDecoration(labelText: 'Score', border: OutlineInputBorder(), isDense: true),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextFormField(
                                controller: maxCtrls[key],
                                decoration: const InputDecoration(labelText: 'Max', border: OutlineInputBorder(), isDense: true),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            if (assessmentKeys.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                                onPressed: () {
                                  setDState(() {
                                    assessmentKeys.remove(key);
                                    scoreCtrls.remove(key);
                                    maxCtrls.remove(key);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Assessment (CAT, Exam, etc.)'),
                      onPressed: () {
                        final name = 'cat${assessmentKeys.length + 1}';
                        setDState(() {
                          assessmentKeys.add(name);
                          scoreCtrls[name] = TextEditingController();
                          maxCtrls[name] = TextEditingController(text: '30');
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: termCtrl,
                            decoration: const InputDecoration(labelText: 'Term', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: yearCtrl,
                            decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder(), isDense: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: commentCtrl,
                      decoration: const InputDecoration(labelText: 'Comments (optional)', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final assessments = <String, AssessmentEntry>{};
                  for (final key in assessmentKeys) {
                    final score = double.tryParse(scoreCtrls[key]?.text ?? '') ?? 0;
                    final max = double.tryParse(maxCtrls[key]?.text ?? '') ?? 0;
                    assessments[key] = AssessmentEntry(score: score, max: max);
                  }

                  final grade = GradeRecord(
                    id: existing?.id ?? '',
                    studentId: studentId,
                    studentName: studentName,
                    subjectName: subjectCtrl.text,
                    classId: widget.classId,
                    term: termCtrl.text,
                    academicYear: yearCtrl.text,
                    assessments: assessments,
                    teacherId: context.read<AuthProvider>().currentUserId,
                    teacherName: context.read<AuthProvider>().currentUser?.fullName ?? '',
                    comments: commentCtrl.text,
                  );
                  if (existing != null) {
                    await _service.saveGrade(grade);
                  } else {
                    await _service.createGrade(grade);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text('Grades: ${widget.classId}')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('enrolledClasses', arrayContains: widget.classId)
            .snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userSnap.hasError) {
            return Center(child: Text('Error: ${userSnap.error}'));
          }
          var rawDocs = userSnap.data?.docs ?? [];
          rawDocs.sort((a, b) {
            final nameA = ((a.data() as Map<String, dynamic>)['fullName'] as String? ?? '').toLowerCase();
            final nameB = ((b.data() as Map<String, dynamic>)['fullName'] as String? ?? '').toLowerCase();
            return nameA.compareTo(nameB);
          });
          final students = rawDocs;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search students...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<GradeRecord>>(
                  stream: _service.getGradesForClass(widget.classId),
                  builder: (context, gradeSnap) {
                    final allGrades = gradeSnap.data ?? [];

                    final filtered = students.where((doc) {
                      final name = (doc.data() as Map<String, dynamic>)['fullName'] as String? ?? '';
                      return name.toLowerCase().contains(_searchQuery);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text('No students enrolled', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final data = filtered[index].data() as Map<String, dynamic>;
                        final sid = filtered[index].id;
                        final name = data['fullName'] ?? 'Unknown';
                        final regNo = data['registrationNumber'] ?? '';

                        final studentGrades = allGrades.where((g) => g.studentId == sid).toList();
                        final avg = studentGrades.isEmpty
                            ? null
                            : studentGrades.map((g) => g.percentage).reduce((a, b) => a + b) / studentGrades.length;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              child: Text(name.toString()[0].toUpperCase(),
                                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('$regNo · ${studentGrades.length} subjects${avg != null ? ' · Avg: ${avg.toStringAsFixed(1)}%' : ''}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            children: [
                              ...studentGrades.map((g) {
                                final assessmentsStr = g.assessments.entries.map((e) =>
                                  '${e.key}: ${e.value.score.toStringAsFixed(0)}/${e.value.max.toStringAsFixed(0)}'
                                ).join(' | ');
                                return ListTile(
                                  dense: true,
                                  title: Text(g.subjectName),
                                  subtitle: Text('$assessmentsStr\n${g.grade} · ${g.percentage.toStringAsFixed(1)}% · ${g.term} ${g.academicYear}'),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _showGradeEditor(g, sid, name.toString()),
                                  ),
                                );
                              }),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                                child: TextButton.icon(
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Subject Grade'),
                                  onPressed: () => _showGradeEditor(null, sid, name.toString()),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
