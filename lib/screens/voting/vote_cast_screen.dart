// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/election.dart';
import '../../services/auth_provider.dart';
import '../../services/voting_service.dart';

class VoteCastScreen extends StatefulWidget {
  final String electionId;
  final String studentId;

  const VoteCastScreen({
    super.key,
    required this.electionId,
    required this.studentId,
  });

  @override
  State<VoteCastScreen> createState() => _VoteCastScreenState();
}

class _VoteCastScreenState extends State<VoteCastScreen> {
  final VotingService _service = VotingService();
  final Map<String, String> _selections = {}; // positionId -> candidateId
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cast Your Vote')),
      body: StreamBuilder<List<Position>>(
        stream: _service.getPositionsStream(widget.electionId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final positions = snapshot.data!;
          if (positions.isEmpty) {
            return const Center(child: Text('No positions available.'));
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: positions.length,
                  itemBuilder: (context, index) => _PositionSection(
                    position: positions[index],
                    electionId: widget.electionId,
                    selectedCandidateId: _selections[positions[index].id],
                    onSelected: (candidateId) {
                      setState(() {
                        _selections[positions[index].id] = candidateId;
                      });
                    },
                  ),
                ),
              ),
              _buildSubmitBar(positions.length),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubmitBar(int totalPositions) {
    final allSelected = _selections.length == totalPositions;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_selections.length} of $totalPositions positions selected',
              style: TextStyle(
                fontSize: 13,
                color: allSelected ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: (allSelected && !_isSubmitting)
                    ? _confirmAndSubmit
                    : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Vote',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndSubmit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Your Vote'),
        content: const Text(
          'Once submitted, your vote cannot be changed. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      for (final entry in _selections.entries) {
        await _service.castVote(
          electionId: widget.electionId,
          positionId: entry.key,
          candidateId: entry.value,
          studentId: widget.studentId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _PositionSection extends StatefulWidget {
  final Position position;
  final String electionId;
  final String? selectedCandidateId;
  final ValueChanged<String> onSelected;

  const _PositionSection({
    required this.position,
    required this.electionId,
    required this.selectedCandidateId,
    required this.onSelected,
  });

  @override
  State<_PositionSection> createState() => _PositionSectionState();
}

class _PositionSectionState extends State<_PositionSection> {
  bool _hasVoted = false;

  @override
  void initState() {
    super.initState();
    _checkVoteStatus();
  }

  Future<void> _checkVoteStatus() async {
    final userId = context.read<AuthProvider>().currentUserId;
    final voted = await VotingService().hasVoted(
      widget.electionId,
      widget.position.id,
      userId,
    );
    if (mounted) setState(() => _hasVoted = voted);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.position.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (_hasVoted) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Voted',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Candidate>>(
              stream: VotingService().getCandidatesStream(
                widget.electionId,
                widget.position.id,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final candidates = snapshot.data!;
                return Column(
                  children: candidates.map((candidate) {
                    return ListTile(
                      leading: Radio<String>(
                        value: candidate.id,
                        groupValue: widget.selectedCandidateId,
                        onChanged: _hasVoted
                            ? null
                            : (val) {
                                if (val != null) widget.onSelected(val);
                              },
                      ),
                      title: Text(
                        '${candidate.candidateNumber}. ${candidate.name}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: candidate.manifesto.isNotEmpty
                          ? Text(
                              candidate.manifesto,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                      onTap: _hasVoted
                          ? null
                          : () => widget.onSelected(candidate.id),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
