// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/election.dart';
import '../../services/voting_service.dart';
import '../../services/auth_provider.dart';
import 'vote_cast_screen.dart';
import 'results_screen.dart';

class VotingDashboardScreen extends StatelessWidget {
  const VotingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Elections')),
      body: StreamBuilder<List<Election>>(
        stream: VotingService().getElectionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final elections = snapshot.data ?? [];
          if (elections.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.how_to_vote,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Elections',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Elections will appear here once created.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: elections.length,
            itemBuilder: (context, index) =>
                _ElectionCard(election: elections[index]),
          );
        },
      ),
    );
  }
}

class _ElectionCard extends StatelessWidget {
  final Election election;
  const _ElectionCard({required this.election});

  Color _statusColor() {
    switch (election.status) {
      case 'active':
        return Colors.green;
      case 'closed':
        return Colors.orange;
      case 'results_published':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final now = DateTime.now();
    final isActive = election.isActiveNow;
    final canViewResults =
        election.resultsPublic && now.isAfter(election.endDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.how_to_vote, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        election.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          election.statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  '${election.startDate.day}/${election.startDate.month} — ${election.endDate.day}/${election.endDate.month}/${election.endDate.year}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (isActive)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final userId = context
                            .read<AuthProvider>()
                            .currentUserId;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VoteCastScreen(
                              electionId: election.id,
                              studentId: userId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.how_to_vote, size: 18),
                      label: const Text('Vote Now'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ),
                if (isActive) const SizedBox(width: 8),
                if (canViewResults)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ResultsScreen(
                              electionId: election.id,
                              title: election.title,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bar_chart, size: 18),
                      label: const Text('View Results'),
                    ),
                  ),
                if (!isActive && !canViewResults)
                  Text(
                    election.isVotingClosed
                        ? 'Voting period has ended'
                        : 'Voting opens ${election.startDate.day}/${election.startDate.month}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
