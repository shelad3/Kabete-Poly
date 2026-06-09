import 'package:flutter/material.dart';
import '../../models/quiz.dart';
import '../../services/quiz_service.dart';
import '../../widgets/shimmer_loading.dart';

class QuizResultsScreen extends StatelessWidget {
  final Quiz quiz;
  const QuizResultsScreen({super.key, required this.quiz});

  @override
  Widget build(BuildContext context) {
    final service = QuizService();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(quiz.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'publish') {
                await service.updateQuiz(quiz.id, {'isPublished': true});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Quiz published')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              if (!quiz.isPublished)
                const PopupMenuItem(value: 'publish', child: Text('Publish Quiz')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<QuizSubmission>>(
        stream: service.getSubmissionsStream(quiz.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const ShimmerNotificationList();
          }
          if (snap.hasError) {
            return Center(child: Text('Error loading results: ${snap.error}'));
          }

          final submissions = snap.data ?? [];

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(quiz.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${quiz.durationMinutes} min · ${quiz.questionIds.length} questions',
                              style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text('${submissions.length}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text('Submissions', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
              if (submissions.isEmpty)
                const Expanded(
                  child: Center(child: Text('No submissions yet')),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: submissions.length,
                    itemBuilder: (context, index) {
                      final s = submissions[index];
                      final pct = s.percentage;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: pct >= 50 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                            child: Text('${pct.round()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: pct >= 50 ? Colors.green : Colors.red,
                                )),
                          ),
                          title: Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${s.score}/${s.total} · ${_formatDate(s.submittedAt)}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
