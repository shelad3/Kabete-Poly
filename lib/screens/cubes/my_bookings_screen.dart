// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/cube_service.dart';
import '../../services/auth_provider.dart';
import '../../models/cube_booking.dart';
import '../../models/waitlist_entry.dart';
import '../../utils/term_utils.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final CubeService _service = CubeService();

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Theme.of(context).colorScheme.primary;
      case 'checked_in':
        return Colors.green;
      case 'completed':
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case 'cancelled':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'checked_in':
        return Icons.verified;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _statusTitle(String status) {
    switch (status) {
      case 'pending':
        return 'Awaiting Confirmation';
      case 'confirmed':
        return 'Booking Confirmed';
      case 'checked_in':
        return 'Currently Staying';
      case 'completed':
        return 'Stay Completed';
      case 'cancelled':
        return 'Booking Cancelled';
      default:
        return status;
    }
  }

  String _statusDescription(String status) {
    switch (status) {
      case 'pending':
        return 'Your booking request has been submitted and is awaiting admin confirmation.';
      case 'confirmed':
        return 'Your cubicle has been confirmed. Check in on or after the check-in date.';
      case 'checked_in':
        return 'You are currently occupying this cubicle. Remember to check out before the end of term.';
      case 'completed':
        return 'Your stay for this term is complete. You cannot book another cubicle this term.';
      case 'cancelled':
        return 'This booking has been cancelled.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Bookings — ${TermUtils.getCurrentTermLabel()}'),
      ),
      body: StreamBuilder<List<CubeBooking>>(
        stream: _service.getMyBookingsStream(userId),
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
                    Icons.book_online,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No bookings this term',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Book a cubicle from the Houses tab',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Active/Recent booking with enhanced status
              ...bookings.map(
                (b) => _EnhancedBookingCard(
                  booking: b,
                  statusColor: _statusColor,
                  paymentColor: _paymentColor,
                  statusIcon: _statusIcon,
                  statusTitle: _statusTitle,
                  statusDescription: _statusDescription,
                  onCancel: b.status == 'pending' || b.status == 'confirmed'
                      ? () => _cancelBooking(b)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              // Waitlist section
              _WaitlistSection(userId: userId),
            ],
          );
        },
      ),
    );
  }

  Future<void> _cancelBooking(CubeBooking booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text('Cancel ${booking.cubeLabel} in ${booking.houseName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _service.cancelBooking(booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

class _EnhancedBookingCard extends StatelessWidget {
  final CubeBooking booking;
  final Color Function(String) statusColor;
  final Color Function(String) paymentColor;
  final IconData Function(String) statusIcon;
  final String Function(String) statusTitle;
  final String Function(String) statusDescription;
  final VoidCallback? onCancel;

  const _EnhancedBookingCard({
    required this.booking,
    required this.statusColor,
    required this.paymentColor,
    required this.statusIcon,
    required this.statusTitle,
    required this.statusDescription,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(booking.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Icon(Icons.workspaces, color: color, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${booking.cubeLabel} — ${booking.houseName}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        statusTitle(booking.status),
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon(booking.status), size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        booking.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Status-specific info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusDescription(booking.status),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Metadata row
            Row(
              children: [
                Icon(
                  Icons.payments,
                  size: 14,
                  color: paymentColor(booking.paymentStatus),
                ),
                const SizedBox(width: 4),
                Text(
                  booking.paymentStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: paymentColor(booking.paymentStatus),
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.calendar_month,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Term ${booking.term} ${booking.year}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WaitlistSection extends StatelessWidget {
  final String? userId;
  const _WaitlistSection({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<List<WaitlistEntry>>(
      stream: CubeService().getMyWaitlistStream(userId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final entries = snapshot.data!
            .where((e) => e.status == 'waiting')
            .toList();
        if (entries.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Waiting List',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ...entries.map(
              (entry) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Text(
                      '${entry.position}',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    '${entry.houseName} — Cube ${entry.cubeNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(entry.positionLabel),
                  trailing: IconButton(
                    icon: const Icon(Icons.cancel_outlined, size: 20),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Leave Waiting List?'),
                          content: const Text(
                            'You will lose your position in the queue.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('No'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Yes'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await CubeService().cancelWaitlistEntry(entry.id);
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
