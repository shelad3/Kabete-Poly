// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/feature_flag.dart';
import '../../providers/feature_flag_provider.dart';
import '../../services/auth_provider.dart';

class FeatureFlagManagementScreen extends StatefulWidget {
  const FeatureFlagManagementScreen({super.key});

  @override
  State<FeatureFlagManagementScreen> createState() =>
      _FeatureFlagManagementScreenState();
}

class _FeatureFlagManagementScreenState
    extends State<FeatureFlagManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feature Flags')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Enable or disable features on the go',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Consumer<FeatureFlagProvider>(
              builder: (context, provider, _) {
                final flags = provider.getAllFlags();
                if (flags.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        const Text('No feature flags found'),
                        const Text('Defaults will be seeded on first load.'),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: flags.length,
                  itemBuilder: (context, index) =>
                      _FeatureFlagTile(flag: flags[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureFlagTile extends StatefulWidget {
  final FeatureFlag flag;
  const _FeatureFlagTile({required this.flag});

  @override
  State<_FeatureFlagTile> createState() => _FeatureFlagTileState();
}

class _FeatureFlagTileState extends State<_FeatureFlagTile> {
  late bool _enabled;
  DateTime? _autoDisableAt;
  DateTime? _autoEnableAt;
  bool _hasSchedule = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.flag.enabled;
    _autoDisableAt = widget.flag.autoDisableAt;
    _autoEnableAt = widget.flag.autoEnableAt;
    _hasSchedule = _autoDisableAt != null || _autoEnableAt != null;
  }

  Color _getIconColor() {
    if (!_enabled) return Theme.of(context).colorScheme.onSurfaceVariant;
    switch (widget.flag.name) {
      case 'hostel_booking':
        return Theme.of(context).colorScheme.primary;
      case 'quizzes':
        return Colors.orange;
      case 'forum':
        return Theme.of(context).colorScheme.primary;
      case 'report_cards':
        return Colors.green;
      case 'grades':
        return Theme.of(context).colorScheme.primary;
      case 'timetable':
        return Theme.of(context).colorScheme.primary;
      case 'notifications':
        return Colors.red;
      case 'gallery':
        return Colors.pink;
      case 'campus_map':
        return Theme.of(context).colorScheme.primary;
      case 'lesson_verification':
        return Theme.of(context).colorScheme.primary;
      case 'exam_booking':
        return Colors.deepOrange;
      case 'voting':
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData _getIcon() {
    switch (widget.flag.name) {
      case 'hostel_booking':
        return Icons.bed;
      case 'quizzes':
        return Icons.quiz;
      case 'forum':
        return Icons.forum;
      case 'report_cards':
        return Icons.assessment;
      case 'grades':
        return Icons.grade;
      case 'timetable':
        return Icons.calendar_month;
      case 'notifications':
        return Icons.notifications;
      case 'gallery':
        return Icons.photo_library;
      case 'campus_map':
        return Icons.map;
      case 'lesson_verification':
        return Icons.qr_code_scanner;
      case 'exam_booking':
        return Icons.school;
      case 'voting':
        return Icons.how_to_vote;
      default:
        return Icons.flag;
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    final provider = context.read<FeatureFlagProvider>();
    final authProvider = context.read<AuthProvider>();
    await provider.updateFlag(
      flagId: widget.flag.id,
      flagName: widget.flag.name,
      enabled: value,
      autoDisableAt: _autoDisableAt,
      autoEnableAt: _autoEnableAt,
      adminUid: authProvider.currentUserId,
    );
  }

  Future<void> _pickScheduleDate({required bool isDisable}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isDisable
          ? (_autoDisableAt ?? DateTime.now())
          : (_autoEnableAt ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isDisable) {
        _autoDisableAt = dt;
      } else {
        _autoEnableAt = dt;
      }
      _hasSchedule = true;
    });

    final provider = context.read<FeatureFlagProvider>();
    final authProvider = context.read<AuthProvider>();
    await provider.updateFlag(
      flagId: widget.flag.id,
      flagName: widget.flag.name,
      enabled: _enabled,
      autoDisableAt: _autoDisableAt,
      autoEnableAt: _autoEnableAt,
      adminUid: authProvider.currentUserId,
    );
  }

  void _clearSchedule() {
    setState(() {
      _autoDisableAt = null;
      _autoEnableAt = null;
      _hasSchedule = false;
    });
    final provider = context.read<FeatureFlagProvider>();
    final authProvider = context.read<AuthProvider>();
    provider.updateFlag(
      flagId: widget.flag.id,
      flagName: widget.flag.name,
      enabled: _enabled,
      autoDisableAt: null,
      autoEnableAt: null,
      adminUid: authProvider.currentUserId ?? '',
    );
  }

  String _formatDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getIconColor();
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getIcon(), color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.flag.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (widget.flag.description.isNotEmpty)
                        Text(
                          widget.flag.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _enabled,
                  onChanged: _toggle,
                  activeColor: color,
                ),
              ],
            ),
            if (!_enabled && widget.flag.disabledMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Disabled message: "${widget.flag.disabledMessage}"',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Schedule',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (_hasSchedule)
                  TextButton.icon(
                    onPressed: _clearSchedule,
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            if (_hasSchedule) ...[
              if (_autoDisableAt != null)
                _ScheduleChip(
                  label: 'Auto-disable',
                  date: _formatDate(_autoDisableAt!),
                  color: Colors.red,
                  onTap: () => _pickScheduleDate(isDisable: true),
                ),
              if (_autoEnableAt != null)
                _ScheduleChip(
                  label: 'Auto-enable',
                  date: _formatDate(_autoEnableAt!),
                  color: Colors.green,
                  onTap: () => _pickScheduleDate(isDisable: false),
                ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickScheduleDate(isDisable: true),
                      icon: const Icon(Icons.pause_circle_outline, size: 16),
                      label: const Text('Set auto-disable'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickScheduleDate(isDisable: false),
                      icon: const Icon(Icons.play_circle_outline, size: 16),
                      label: const Text('Set auto-enable'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
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

class _ScheduleChip extends StatelessWidget {
  final String label;
  final String date;
  final Color color;
  final VoidCallback onTap;

  const _ScheduleChip({
    required this.label,
    required this.date,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$label: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
              Text(
                date,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
