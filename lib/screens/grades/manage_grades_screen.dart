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
    final cat1Ctrl = TextEditingController(text: existing?.cat1Score.toStringAsFixed(0) ?? '');
    final cat2Ctrl = TextEditingController(text: existing?.cat2Score.toStringAsFixed(0) ?? '');
    final examCtrl = TextEditingController(text: existing?.examScore.toStringAsFixed(0) ?? '');
    final commentCtrl = TextEditingController(text: existing?.comments ?? '');
    final termCtrl = TextEditingController(text: existing?.term ?? 'Term 1');
    final yearCtrl = TextEditingController(text: existing?.academicYear ?? '2026');
    final subjectCtrl = TextEditingController(text: existing?.subjectName ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing != null ? 'Edit Grade' : 'Add Grade'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Student: $studentName', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: subjectCtrl,
                  decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: cat1Ctrl,
                        decoration: const InputDecoration(labelText: 'CAT 1 (0-30)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => v != null && double.tryParse(v) == null ? 'Invalid' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: cat2Ctrl,
                        decoration: const InputDecoration(labelText: 'CAT 2 (0-30)', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        validator: (v) => v != null && double.tryParse(v) == null ? 'Invalid' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: examCtrl,
                  decoration: const InputDecoration(labelText: 'Exam Score (0-40)', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) => v != null && double.tryParse(v) == null ? 'Invalid' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: termCtrl,
                        decoration: const InputDecoration(labelText: 'Term', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: yearCtrl,
                        decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
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
              final grade = GradeRecord(
                id: existing?.id ?? '',
                studentId: studentId,
                studentName: studentName,
                subjectName: subjectCtrl.text,
                classId: widget.classId,
                term: termCtrl.text,
                academicYear: yearCtrl.text,
                cat1Score: double.tryParse(cat1Ctrl.text) ?? 0,
                cat1Max: 30,
                cat2Score: double.tryParse(cat2Ctrl.text) ?? 0,
                cat2Max: 30,
                examScore: double.tryParse(examCtrl.text) ?? 0,
                examMax: 40,
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
                              ...studentGrades.map((g) => ListTile(
                                dense: true,
                                title: Text(g.subjectName),
                                subtitle: Text('${g.grade} · ${g.totalScore}/${g.totalMax} (${g.percentage.toStringAsFixed(1)}%) · ${g.term}'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showGradeEditor(g, sid, name.toString()),
                                ),
                              )),
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
