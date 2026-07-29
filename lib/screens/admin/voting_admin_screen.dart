// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/election.dart';
import '../../services/voting_service.dart';

class VotingAdminScreen extends StatefulWidget {
  const VotingAdminScreen({super.key});

  @override
  State<VotingAdminScreen> createState() => _VotingAdminScreenState();
}

class _VotingAdminScreenState extends State<VotingAdminScreen> {
  final VotingService _service = VotingService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Elections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateElectionDialog(),
          ),
        ],
      ),
      body: StreamBuilder<List<Election>>(
        stream: _service.getElectionsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final elections = snapshot.data!;
          if (elections.isEmpty) {
            return const Center(
              child: Text('No elections. Tap + to create one.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: elections.length,
            itemBuilder: (context, index) {
              final election = elections[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    election.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${election.statusLabel} | ${election.startDate.day}/${election.startDate.month} — ${election.endDate.day}/${election.endDate.month}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) =>
                        _handleElectionAction(election, action),
                    itemBuilder: (ctx) => [
                      if (election.status == 'setup')
                        const PopupMenuItem(
                          value: 'activate',
                          child: Text('Activate Election'),
                        ),
                      if (election.status == 'active') ...[
                        const PopupMenuItem(
                          value: 'close',
                          child: Text('Close Voting'),
                        ),
                        const PopupMenuItem(
                          value: 'add_position',
                          child: Text('Add Position'),
                        ),
                      ],
                      if (election.status == 'closed')
                        const PopupMenuItem(
                          value: 'publish',
                          child: Text('Publish Results'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateElectionDialog() {
    final titleCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Create Election'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Election Title',
                    hintText: 'e.g., KAPOSA 2026 Elections',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start Date'),
                  subtitle: Text(
                    '${startDate.day}/${startDate.month}/${startDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDState(() => startDate = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('End Date'),
                  subtitle: Text(
                    '${endDate.day}/${endDate.month}/${endDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: endDate,
                      firstDate: startDate,
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDState(() => endDate = picked);
                    }
                  },
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
                if (titleCtrl.text.isEmpty) return;
                await _service.createElection(
                  title: titleCtrl.text.trim(),
                  startDate: startDate,
                  endDate: endDate,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleElectionAction(Election election, String action) async {
    switch (action) {
      case 'activate':
        await _service.activateElection(election.id);
        break;
      case 'close':
        await _service.closeElection(election.id);
        break;
      case 'publish':
        await _service.publishResults(election.id);
        break;
      case 'add_position':
        _showAddPositionDialog(election.id);
        break;
    }
  }

  void _showAddPositionDialog(String electionId) {
    final titleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Position'),
        content: TextField(
          controller: titleCtrl,
          decoration: const InputDecoration(
            labelText: 'Position Title',
            hintText: 'e.g., President',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (titleCtrl.text.isEmpty) return;
              await _service.addPosition(
                electionId: electionId,
                title: titleCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
