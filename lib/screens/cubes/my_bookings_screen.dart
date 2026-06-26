import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/cube_service.dart';
import '../../services/auth_provider.dart';
import '../../models/cube_booking.dart';
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
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'checked_in': return Colors.green;
      case 'completed': return Colors.grey;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Color _paymentColor(String status) {
    switch (status) {
      case 'paid': return Colors.green;
      default: return Colors.red;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.hourglass_empty;
      case 'confirmed': return Icons.check_circle_outline;
      case 'checked_in': return Icons.verified;
      case 'completed': return Icons.done_all;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().currentUserId;

    return Scaffold(
      appBar: AppBar(title: Text('My Bookings — ${TermUtils.getCurrentTermLabel()}')),
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
                  Icon(Icons.book_online, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No bookings this term', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Book a cubicle from the Houses tab', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bookings.length,
            itemBuilder: (_, i) => _BookingCard(
              booking: bookings[i],
              statusColor: _statusColor,
              paymentColor: _paymentColor,
              statusIcon: _statusIcon,
              onCancel: bookings[i].status == 'pending' || bookings[i].status == 'confirmed'
                  ? () => _cancelBooking(bookings[i])
                  : null,
            ),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, Cancel')),
        ],
      ),
    );
    if (confirm == true) {
      await _service.cancelBooking(booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled'), backgroundColor: Colors.green),
        );
      }
    }
  }
}

class _BookingCard extends StatelessWidget {
  final CubeBooking booking;
  final Color Function(String) statusColor;
  final Color Function(String) paymentColor;
  final IconData Function(String) statusIcon;
  final VoidCallback? onCancel;

  const _BookingCard({
    required this.booking,
    required this.statusColor,
    required this.paymentColor,
    required this.statusIcon,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.workspaces, color: Colors.blue[400], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${booking.cubeLabel} — ${booking.houseName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor(booking.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon(booking.status), size: 14, color: statusColor(booking.status)),
                      const SizedBox(width: 4),
                      Text(booking.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor(booking.status))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.payments, size: 14, color: paymentColor(booking.paymentStatus)),
                const SizedBox(width: 4),
                Text(booking.paymentStatus.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: paymentColor(booking.paymentStatus))),
                const SizedBox(width: 16),
                Icon(Icons.calendar_month, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Term ${booking.term} ${booking.year}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              ],
            ),
            if (onCancel != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                  label: const Text('Cancel', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
