import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cube.dart';
import '../../models/cube_booking.dart';
import '../../services/cube_service.dart';
import '../../services/auth_provider.dart';

class BookingFormScreen extends StatefulWidget {
  final Cube cube;
  const BookingFormScreen({super.key, required this.cube});

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final CubeService _service = CubeService();
  DateTime _selectedDate = DateTime.now();
  String _startTime = '08:00';
  String _endTime = '10:00';
  bool _isBooking = false;

  static const _timeSlots = [
    '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00', '17:00',
  ];

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final startIdx = _timeSlots.indexOf(_startTime);
    final endIdx = _timeSlots.indexOf(_endTime);
    if (startIdx >= endIdx) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      final available = await _service.isCubeAvailable(
        widget.cube.id, _selectedDate, _startTime, _endTime,
      );
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This cubicle is already booked for that time'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final booking = CubeBooking(
        id: '',
        studentId: context.read<AuthProvider>().currentUserId,
        studentName: user.fullName,
        regNo: user.registrationNumber,
        cubeId: widget.cube.id,
        roomName: widget.cube.roomName,
        cubeLabel: widget.cube.label,
        date: _selectedDate,
        startTime: _startTime,
        endTime: _endTime,
      );

      await _service.createBooking(booking);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cubicle booked successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Book ${widget.cube.label}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.workspaces, size: 40, color: Colors.blue[400]),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.cube.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(widget.cube.roomName, style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
              trailing: const Icon(Icons.edit),
              onTap: _pickDate,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Start Time'),
              trailing: DropdownButton<String>(
                value: _startTime,
                items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _startTime = v!),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('End Time'),
              trailing: DropdownButton<String>(
                value: _endTime,
                items: _timeSlots.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _endTime = v!),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isBooking ? null : _submit,
                icon: _isBooking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.book_online),
                label: Text(_isBooking ? 'Booking...' : 'Confirm Booking'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
