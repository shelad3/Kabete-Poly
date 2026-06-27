import 'package:flutter/material.dart';
import '../../models/cube_booking.dart';

class BookingReceiptScreen extends StatelessWidget {
  final CubeBooking booking;
  const BookingReceiptScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Receipt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 72, color: Colors.green[400]),
            const SizedBox(height: 8),
            Text('Booking ${booking.status == 'confirmed' ? 'Confirmed' : 'Pending'}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[700])),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(context, Icons.home, 'House', booking.houseName),
                  const Divider(height: 24),
                  _row(context, Icons.workspaces, 'Cubicle', booking.cubeLabel),
                  const Divider(height: 24),
                  _row(context, Icons.person, 'Student', booking.studentName),
                  const Divider(height: 24),
                  _row(context, Icons.badge, 'Reg No', booking.regNo),
                  const Divider(height: 24),
                  _row(context, Icons.calendar_month, 'Term', 'Term ${booking.term} ${booking.year}'),
                  const Divider(height: 24),
                  _row(context, Icons.payments, 'Payment', booking.paymentStatus.toUpperCase()),
                  const Divider(height: 24),
                  _row(context, Icons.info_outline, 'Status', booking.status.replaceAll('_', ' ').toUpperCase()),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      booking.status == 'confirmed'
                          ? 'Your booking has been approved. Report to the lab on time.'
                          : 'Your booking is pending approval. Check back later.',
                      style: TextStyle(color: Colors.amber[800], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ),
      ],
    );
  }
}
