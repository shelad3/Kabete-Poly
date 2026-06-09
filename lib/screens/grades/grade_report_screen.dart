import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                                  child: Text(g.grade,
                                      style: TextStyle(
                                        color: _gradeColor(g.grade),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      )),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildScoreBadge('CAT 1', g.cat1Score, g.cat1Max),
                                const SizedBox(width: 8),
                                _buildScoreBadge('CAT 2', g.cat2Score, g.cat2Max),
                                const SizedBox(width: 8),
                                _buildScoreBadge('Exam', g.examScore, g.examMax),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text('Total: ${g.totalScore}/${g.totalMax}',
                                    style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
                                const Spacer(),
                                Text('${g.percentage.toStringAsFixed(1)}%',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                              ],
                            ),
                            if (g.comments != null && g.comments!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(g.comments!, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic)),
                            ],
                            const SizedBox(height: 4),
                            Text('${g.term} ${g.academicYear} · ${g.teacherName}',
                                style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                          ],
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

  Widget _buildScoreBadge(String label, double score, double max) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text('${score.toStringAsFixed(0)}/${max.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
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
}
