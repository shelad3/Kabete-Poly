// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import '../../models/election.dart';
import '../../services/voting_service.dart';

class ResultsScreen extends StatefulWidget {
  final String electionId;
  final String title;

  const ResultsScreen({
    super.key,
    required this.electionId,
    required this.title,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  Map<String, List<Candidate>> _results = {};
  int _totalVotes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final results = await VotingService().getResults(widget.electionId);
    final turnout = await VotingService().getTurnout(widget.electionId);
    if (mounted) {
      setState(() {
        _results = results;
        _totalVotes = turnout;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} Results')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  const Text('Results not yet available'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Summary card
                Card(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _SummaryStat(
                          label: 'Positions',
                          value: '${_results.length}',
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        _SummaryStat(
                          label: 'Total Votes',
                          value: '$_totalVotes',
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Results by position
                ..._results.entries.map((entry) {
                  final candidates = entry.value;
                  if (candidates.isEmpty) return const SizedBox.shrink();
                  final totalForPosition = candidates.fold<int>(
                    0,
                    (sum, c) => sum + c.voteCount,
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Position ${entry.key}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...candidates.asMap().entries.map((ci) {
                            final candidate = ci.value;
                            final percentage = totalForPosition > 0
                                ? (candidate.voteCount / totalForPosition * 100)
                                : 0.0;
                            final isWinner = ci.key == 0;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isWinner)
                                        Icon(
                                          Icons.emoji_events,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          size: 20,
                                        ),
                                      if (!isWinner)
                                        Text(
                                          '${candidate.candidateNumber}',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          candidate.name,
                                          style: TextStyle(
                                            fontWeight: isWinner
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${candidate.voteCount} (${percentage.toStringAsFixed(1)}%)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isWinner
                                              ? Colors.green.shade700
                                              : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: totalForPosition > 0
                                          ? candidate.voteCount /
                                                totalForPosition
                                          : 0,
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                      color: isWinner
                                          ? Colors.green
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      minHeight: 8,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}
