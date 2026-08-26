// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/exam.dart';
import '../../services/exam_booking_service.dart';
import '../../services/auth_provider.dart';
import '../../services/class_provider.dart';

class ExamBookingScreen extends StatelessWidget {
  const ExamBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Examination Booking'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Available Exams'),
              Tab(text: 'My Registrations'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_AvailableExamsTab(), _MyRegistrationsTab()],
        ),
      ),
    );
  }
}

class _AvailableExamsTab extends StatelessWidget {
  const _AvailableExamsTab();

  @override
  Widget build(BuildContext context) {
    final classId = context.watch<ClassProvider>().currentClass;
    if (classId.isEmpty) {
      return const Center(child: Text('No class selected.'));
    }

    return StreamBuilder<List<Exam>>(
      stream: ExamBookingService().getAvailableExamsStream(classId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final exams = snapshot.data ?? [];
        if (exams.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Exams Available',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Exam registration will appear here\nonce published by administration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: exams.length,
          itemBuilder: (context, index) => _ExamCard(exam: exams[index]),
        );
      },
    );
  }
}

class _ExamCard extends StatefulWidget {
  final Exam exam;
  const _ExamCard({required this.exam});

  @override
  State<_ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends State<_ExamCard> {
  bool? _isRegistered;
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _checkRegistration();
  }

  Future<void> _checkRegistration() async {
    final userId = context.read<AuthProvider>().currentUserId;
    final registered = await ExamBookingService().isRegistered(
      userId,
      widget.exam.id,
    );
    if (mounted) setState(() => _isRegistered = registered);
  }

  Color _getTypeColor() {
    switch (widget.exam.type) {
      case 'midterm':
        return Colors.orange;
      case 'final':
        return Colors.red;
      case 'cat':
        return Theme.of(context).colorScheme.primary;
      case 'supplementary':
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final typeColor = _getTypeColor();
    final isOpen = exam.isRegistrationOpen;

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
                Expanded(
                  child: Text(
                    exam.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    exam.typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: typeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${exam.startDate.day}/${exam.startDate.month}/${exam.startDate.year} — ${exam.endDate.day}/${exam.endDate.month}/${exam.endDate.year}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.event_available,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Registration deadline: ${exam.registrationDeadline.day}/${exam.registrationDeadline.month}/${exam.registrationDeadline.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.people,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${exam.availableSeats} of ${exam.maxSeats} seats available',
                  style: TextStyle(
                    fontSize: 12,
                    color: exam.availableSeats < 20
                        ? Colors.red
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_isRegistered == true)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Registered',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (_isRegistering)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (isOpen)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _register,
                  icon: const Icon(Icons.app_registration, size: 18),
                  label: const Text('Register'),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  exam.hasStarted ? 'Exam in progress' : 'Registration closed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _register() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register for Exam'),
        content: Text('Register for "${widget.exam.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Register'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRegistering = true);

    try {
      final userId = context.read<AuthProvider>().currentUserId;
      await ExamBookingService().registerForExam(
        studentId: userId,
        examId: widget.exam.id,
      );
      if (mounted) {
        setState(() {
          _isRegistered = true;
          _isRegistering = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegistering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _MyRegistrationsTab extends StatelessWidget {
  const _MyRegistrationsTab();

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().currentUserId;

    return StreamBuilder<List<ExamBooking>>(
      stream: ExamBookingService().getMyExamBookingsStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data ?? [];
        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.app_registration,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Registrations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Register for exams from the Available tab.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (context, index) {
            final booking = bookings[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                  child: const Icon(Icons.check_circle, color: Colors.green),
                ),
                title: Text(
                  booking.examId,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Status: ${booking.status} | ${booking.registeredCourseIds.length} courses',
                ),
                trailing: Text(
                  '${booking.registeredAt.day}/${booking.registeredAt.month}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
