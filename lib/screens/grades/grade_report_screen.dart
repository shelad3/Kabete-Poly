import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_provider.dart';
import '../../services/grade_service.dart';
import '../../models/grade_record.dart';
import '../../widgets/shimmer_loading.dart';

class GradeReportScreen extends StatelessWidget {
  const GradeReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().currentUserId;
    final service = GradeService();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('My Grades')),
      body: StreamBuilder<List<GradeRecord>>(
        stream: service.getGradesForStudent(userId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const ShimmerExploreList();
          }
          if (snap.hasError) {
            return Center(child: Text('Error loading grades: ${snap.error}'));
          }
          final grades = snap.data ?? [];
          if (grades.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grade_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No grades recorded yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                ],
              ),
            );
          }

          // Group by class/term/year
          final grouped = <String, List<GradeRecord>>{};
          for (final g in grades) {
            final key = '${g.classId} | ${g.term} ${g.academicYear}';
            grouped.putIfAbsent(key, () => []).add(g);
          }

          final overallPct = grades.isEmpty ? 0.0 : grades.map((g) => g.percentage).reduce((a, b) => a + b) / grades.length;
          final overallGrade = _gradeFromPct(overallPct);

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Overall Average', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          const SizedBox(height: 4),
                          Text('${overallPct.toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('Grade: $overallGrade',
                              style: TextStyle(fontSize: 16, color: _gradeColor(overallGrade), fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Text('${grades.length} subjects', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grades.length,
                  itemBuilder: (context, index) {
                    final g = grades[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showGradeDetail(context, g),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(g.subjectName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _gradeColor(g.grade).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${g.grade}  ${g.percentage.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        color: _gradeColor(g.grade),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: g.assessments.entries.take(3).map((e) {
                                  return Expanded(
                                    child: _buildMiniBadge(
                                      e.key,
                                      '${e.value.score.toStringAsFixed(0)}/${e.value.max.toStringAsFixed(0)}',
                                    ),
                                  );
                                }).toList(),
                              ),
                              if (g.assessments.length > 3)
                                Text('+${g.assessments.length - 3} more', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                              if (g.comments != null && g.comments!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(g.comments!, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('Tap for details',
                                      style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                  const Spacer(),
                                  Text('${g.term} ${g.academicYear}',
                                      style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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

  void _showGradeDetail(BuildContext context, GradeRecord g) {
    final uid = context.read<AuthProvider>().currentUserId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Center(
                    child: Column(
                      children: [
                        Text(g.subjectName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(g.classId, style: TextStyle(color: Colors.grey[600])),
                        Text('${g.term} ${g.academicYear}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Overall grade circle
                  Center(
                    child: SizedBox(
                      width: 120, height: 120,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: g.percentage / 100,
                            strokeWidth: 10,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(_gradeColor(g.grade)),
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(g.grade, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _gradeColor(g.grade))),
                                Text('${g.percentage.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Assessment breakdown table
                  const Text('Assessment Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Header row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Row(
                            children: const [
                              Expanded(flex: 3, child: Text('Assessment', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(flex: 2, child: Text('Score', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text('%', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                            ],
                          ),
                        ),
                        // Data rows
                        ...g.assessments.entries.map((e) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(_assessmentLabel(e.key), style: const TextStyle(fontWeight: FontWeight.w500))),
                              Expanded(flex: 2, child: Text(
                                '${e.value.score.toStringAsFixed(0)}/${e.value.max.toStringAsFixed(0)}',
                                textAlign: TextAlign.center,
                              )),
                              Expanded(flex: 2, child: Text(
                                '${e.value.percentage.toStringAsFixed(0)}%',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _gradeColorFromPct(e.value.percentage),
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                            ],
                          ),
                        )),
                        // Total row
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A237E).withValues(alpha: 0.05),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            border: Border(top: BorderSide(color: Colors.grey.shade300)),
                          ),
                          child: Row(
                            children: [
                              const Expanded(flex: 3, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(flex: 2, child: Text(
                                '${g.totalScore.toStringAsFixed(0)}/${g.totalMax.toStringAsFixed(0)}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              )),
                              Expanded(flex: 2, child: Text(
                                '${g.percentage.toStringAsFixed(0)}%',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold, color: _gradeColor(g.grade)),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Teacher comment
                  if (g.comments != null && g.comments!.isNotEmpty) ...[
                    const Text("Teacher's Comment", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(g.comments!, style: const TextStyle(fontStyle: FontStyle.italic)),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Attendance records
                  const Text('Attendance Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildAttendanceSection(context, uid, g.classId),

                  const SizedBox(height: 8),
                  Text('Teacher: ${g.teacherName}', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceSection(BuildContext context, String uid, String classId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: uid)
          .where('classId', isEqualTo: classId)
          .orderBy('date', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snap.hasError || !snap.hasData) {
          return Text('No records', style: TextStyle(color: Colors.grey[500]));
        }
        final records = snap.data!.docs;
        if (records.isEmpty) {
          return Text('No attendance records found', style: TextStyle(color: Colors.grey[500]));
        }

        final present = records.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['status'] != 'absent';
        }).length;

        return Column(
          children: [
            Row(
              children: [
                Text('Present: $present/${records.length}',
                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.green[700])),
                const Spacer(),
                Text('${(present / records.length * 100).toStringAsFixed(0)}% attendance',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            ...records.take(5).map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final date = data['date'] ?? '';
              final time = data['time'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('$date  $time', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _assessmentLabel(String key) {
    if (key == 'exam') return 'Final Exam';
    if (key.startsWith('cat')) return 'CAT ${key.replaceAll(RegExp(r'[^0-9]'), '')}';
    return key[0].toUpperCase() + key.substring(1);
  }

  Widget _buildMiniBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(_assessmentLabel(label), style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  String _gradeFromPct(double pct) {
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    return 'E';
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A': return Colors.green;
      case 'B': return Colors.blue;
      case 'C': return Colors.orange;
      case 'D': return Colors.deepOrange;
      default: return Colors.red;
    }
  }

  Color _gradeColorFromPct(double pct) {
    if (pct >= 80) return Colors.green;
    if (pct >= 70) return Colors.blue;
    if (pct >= 60) return Colors.orange;
    if (pct >= 50) return Colors.deepOrange;
    return Colors.red;
  }
}
