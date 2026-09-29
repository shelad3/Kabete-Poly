// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/grade_record.dart';
import '../../services/auth_provider.dart';
import '../../services/grade_service.dart';
import '../../widgets/shimmer_loading.dart';

Color _gradeColor(String grade) {
  switch (grade) {
    case 'A':
      return Colors.green;
    case 'B':
      return Colors.blue;
    case 'C':
      return Colors.orange;
    case 'D':
      return Colors.deepOrange;
    default:
      return Colors.red;
  }
}

int _sortableYear(String key) {
  final m = RegExp(r'(\d{4})$').firstMatch(key);
  return int.tryParse(m?.group(1) ?? '0') ?? 0;
}

int _sortableTerm(String key) {
  final m = RegExp(r'Term\s+(\d+)', caseSensitive: false).firstMatch(key);
  return int.tryParse(m?.group(1) ?? '0') ?? 0;
}

String _termShortLabel(String key) {
  final m = RegExp(r'Term\s+(\d+)', caseSensitive: false).firstMatch(key);
  return m != null ? 'T${m.group(1)}' : 'Term';
}

class GpaTrackerScreen extends StatelessWidget {
  const GpaTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().currentUserId;
    final service = GradeService();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('GPA & Progress')),
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
                  Icon(
                    Icons.insights_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No grades recorded yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final overallGpa =
              grades.map((g) => g.points).reduce((a, b) => a + b) /
                  grades.length;

          final distribution = <String, int>{'A': 0, 'B': 0, 'C': 0, 'D': 0, 'E': 0};
          for (final g in grades) {
            distribution[g.grade] = (distribution[g.grade] ?? 0) + 1;
          }

          final grouped = <String, List<GradeRecord>>{};
          for (final g in grades) {
            final key = '${g.classId} | ${g.term} ${g.academicYear}';
            grouped.putIfAbsent(key, () => []).add(g);
          }
          final termKeys = grouped.keys.toList()
            ..sort((a, b) {
              final byYear = _sortableYear(a).compareTo(_sortableYear(b));
              return byYear != 0
                  ? byYear
                  : _sortableTerm(a).compareTo(_sortableTerm(b));
            });

          final subjectMap = <String, List<GradeRecord>>{};
          for (final g in grades) {
            subjectMap.putIfAbsent(g.subjectName, () => []).add(g);
          }
          final subjects = subjectMap.entries.toList()
            ..sort((a, b) {
              final aa = a.value.map((e) => e.percentage).reduce((x, y) => x + y) /
                  a.value.length;
              final bb = b.value.map((e) => e.percentage).reduce((x, y) => x + y) /
                  b.value.length;
              return bb.compareTo(aa);
            });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _headerCard(context, overallGpa, grades.length, distribution),
              const SizedBox(height: 16),
              _termTrendCard(context, termKeys, grouped),
              const SizedBox(height: 16),
              _subjectsCard(context, subjects),
              const SizedBox(height: 16),
              for (final key in termKeys) ...[
                _termCard(context, key, grouped[key]!),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _headerCard(
    BuildContext context,
    double overallGpa,
    int subjectCount,
    Map<String, int> distribution,
  ) {
    final theme = Theme.of(context);
    final overallGrade = overallGpa >= 3.5
        ? 'A'
        : overallGpa >= 2.5
            ? 'B'
            : overallGpa >= 1.5
                ? 'C'
                : overallGpa >= 0.5
                    ? 'D'
                    : 'E';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  overallGpa.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'out of 4.00',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Grade $overallGrade · $subjectCount subjects',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: distribution.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _gradeColor(e.key).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${e.key}: ${e.value}',
                    style: TextStyle(
                      color: _gradeColor(e.key),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _termTrendCard(
    BuildContext context,
    List<String> termKeys,
    Map<String, List<GradeRecord>> grouped,
  ) {
    final theme = Theme.of(context);
    const barHeight = 100.0;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GPA by term',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: barHeight + 46,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: termKeys.map((key) {
                  final records = grouped[key]!;
                  final gpa =
                      records.map((g) => g.points).reduce((a, b) => a + b) /
                          records.length;
                  final frac = (gpa / 4.0).clamp(0.0, 1.0);
                  final isLatest = key == termKeys.last;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          gpa.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: barHeight * frac,
                          width: 22,
                          decoration: BoxDecoration(
                            color: isLatest
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primary.withValues(alpha: 0.35),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _termShortLabel(key),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subjectsCard(
    BuildContext context,
    List<MapEntry<String, List<GradeRecord>>> subjects,
  ) {
    final theme = Theme.of(context);
    final top = subjects.first;
    final bottom = subjects.last;
    final topAvg =
        top.value.map((e) => e.percentage).reduce((a, b) => a + b) / top.value.length;
    final bottomAvg =
        bottom.value.map((e) => e.percentage).reduce((a, b) => a + b) /
            bottom.value.length;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subject performance',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Strongest: ${top.key} (${topAvg.toStringAsFixed(0)}%)\nNeeds work: ${bottom.key} (${bottomAvg.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final entry in subjects) ...[
              _subjectRow(context, entry.key, entry.value),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _subjectRow(BuildContext context, String name, List<GradeRecord> records) {
    final theme = Theme.of(context);
    final avg = records.map((e) => e.percentage).reduce((a, b) => a + b) /
        records.length;
    final grade = avg >= 80
        ? 'A'
        : avg >= 70
            ? 'B'
            : avg >= 60
                ? 'C'
                : avg >= 50
                    ? 'D'
                    : 'E';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _gradeColor(grade).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$grade ${avg.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _gradeColor(grade),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (avg / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(_gradeColor(grade)),
          ),
        ),
      ],
    );
  }

  Widget _termCard(BuildContext context, String key, List<GradeRecord> records) {
    final theme = Theme.of(context);
    final gpa = records.map((g) => g.points).reduce((a, b) => a + b) / records.length;
    final avg = records.map((e) => e.percentage).reduce((a, b) => a + b) / records.length;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    key,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'GPA ${gpa.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Avg ${avg.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final g in records) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      g.subjectName,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${g.grade}  ${g.percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _gradeColor(g.grade),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}