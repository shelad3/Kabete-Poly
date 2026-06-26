import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/cube_booking.dart';
import '../../services/cube_service.dart';

class ManageCubeBookingsScreen extends StatefulWidget {
  const ManageCubeBookingsScreen({super.key});

  @override
  State<ManageCubeBookingsScreen> createState() => _ManageCubeBookingsScreenState();
}

class _ManageCubeBookingsScreenState extends State<ManageCubeBookingsScreen> {
  final CubeService _service = CubeService();
  String _statusFilter = 'all';

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

  Future<void> _updateStatus(CubeBooking booking, String newStatus) async {
    await _service.updateBookingStatus(booking.id, newStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Bookings'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _statusFilter,
            onSelected: (v) => setState(() => _statusFilter = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'confirmed', child: Text('Confirmed')),
              const PopupMenuItem(value: 'checked_in', child: Text('Checked In')),
              const PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [Icon(Icons.filter_list), SizedBox(width: 4), Text('Filter')],
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<CubeBooking>>(
        stream: _service.getAllBookingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          var bookings = snapshot.data ?? [];
          if (_statusFilter != 'all') {
            bookings = bookings.where((b) => b.status == _statusFilter).toList();
          }
          if (bookings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_online, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No bookings found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bookings.length,
            itemBuilder: (_, i) {
              final b = bookings[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${b.cubeLabel} — ${b.houseName}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor(b.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(b.status.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(b.status))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${b.studentName} (${b.regNo})', style: TextStyle(color: Colors.grey[800])),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(DateFormat('d MMM yyyy').format(b.date), style: TextStyle(color: Colors.grey[700])),
                          const SizedBox(width: 16),
                          Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text('${b.startTime} - ${b.endTime}', style: TextStyle(color: Colors.grey[700])),
                        ],
                      ),
                      if (b.status == 'pending') ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _updateStatus(b, 'confirmed'),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Confirm'),
                              style: TextButton.styleFrom(foregroundColor: Colors.blue),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _updateStatus(b, 'cancelled'),
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text('Reject'),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                            ),
                          ],
                        ),
                      ],
                      if (b.status == 'confirmed') ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _updateStatus(b, 'checked_in'),
                              icon: const Icon(Icons.verified, size: 16),
                              label: const Text('Check In'),
                              style: TextButton.styleFrom(foregroundColor: Colors.green),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _updateStatus(b, 'completed'),
                              icon: const Icon(Icons.done_all, size: 16),
                              label: const Text('Complete'),
                              style: TextButton.styleFrom(foregroundColor: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                      if (b.status == 'checked_in') ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _updateStatus(b, 'completed'),
                            icon: const Icon(Icons.done_all, size: 16),
                            label: const Text('Mark Completed'),
                            style: TextButton.styleFrom(foregroundColor: Colors.grey),
                          ),
                        ),
                      ],
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
}
