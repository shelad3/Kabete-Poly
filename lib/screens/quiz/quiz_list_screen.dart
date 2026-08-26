// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/quiz.dart';
import '../../services/quiz_service.dart';
import '../../services/class_provider.dart';
import '../../services/auth_provider.dart';
import '../../widgets/shimmer_loading.dart';
import 'create_quiz_screen.dart';
import 'take_quiz_screen.dart';
import 'quiz_results_screen.dart';

class QuizListScreen extends StatelessWidget {
  const QuizListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final canCreate =
        user != null && (user.isTeacher || user.isAdmin || user.isLeader);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quizzes'),
        actions: [
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Create Quiz',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateQuizScreen()),
              ),
            ),
        ],
      ),
      body: Consumer<ClassProvider>(
        builder: (context, classProvider, _) {
          final currentClass = classProvider.currentClass;
          final quizService = QuizService();
          return StreamBuilder<List<Quiz>>(
            stream: quizService.getQuizzesStream(currentClass),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const ShimmerExploreList();
              }
              if (snap.hasError) {
                return Center(
                  child: Text('Error loading quizzes: ${snap.error}'),
                );
              }
              final quizzes = snap.data ?? [];
              if (quizzes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.quiz_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No quizzes yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (canCreate) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateQuizScreen(),
                            ),
                          ),
                          child: const Text('Create the first quiz'),
                        ),
                      ],
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: quizzes.length,
                itemBuilder: (context, index) {
                  final quiz = quizzes[index];
                  return _buildQuizCard(context, quiz, user);
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildQuizCard(BuildContext context, Quiz quiz, dynamic user) {
    final isCreator =
        user != null && (user.isTeacher || user.isAdmin || user.isLeader);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (isCreator) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => QuizResultsScreen(quiz: quiz)),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TakeQuizScreen(quiz: quiz)),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: quiz.isPublished
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                child: Icon(
                  quiz.isPublished ? Icons.check_circle : Icons.hourglass_empty,
                  color: quiz.isPublished ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (quiz.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        quiz.description,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${quiz.durationMinutes} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.quiz_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${quiz.questionIds.length} questions',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          quiz.createdBy,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
