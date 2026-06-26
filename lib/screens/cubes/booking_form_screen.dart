import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cube.dart';
import '../../models/house.dart';
import '../../models/cube_booking.dart';
import '../../services/cube_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/term_utils.dart';

class BookingFormScreen extends StatefulWidget {
  final Cube cube;
  final House house;
  const BookingFormScreen({super.key, required this.cube, required this.house});

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final CubeService _service = CubeService();
  final int _term = TermUtils.getCurrentTerm();
  final int _year = TermUtils.getCurrentYear();
  bool _isBooking = false;
  bool _acceptedFee = false;

  Future<void> _submit() async {
    if (!_acceptedFee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the fee terms to continue'), backgroundColor: Colors.red),
      );
      return;
    }

    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    setState(() => _isBooking = true);

    try {
      final available = await _service.isCubeAvailable(
        widget.cube.id, widget.cube.maxOccupancy, _term, _year,
      );
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This cubicle is fully booked'), backgroundColor: Colors.red),
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
        houseId: widget.house.id,
        houseName: widget.house.name,
        cubeNumber: widget.cube.cubeNumber,
        term: _term,
        year: _year,
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
    final fee = 8000;
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
                        Text(widget.house.name, style: TextStyle(color: Colors.grey[600])),
                        Text('Max ${widget.cube.maxOccupancy} students', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_month, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text('${TermUtils.getCurrentTermLabel()} $_year',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payments, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('KSH $fee per term (pay to accounts office)',
                            style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: CheckboxListTile(
                title: const Text('I acknowledge the KSH 8,000 term fee'),
                subtitle: const Text('Pay at the accounts office and update payment status'),
                value: _acceptedFee,
                onChanged: (v) => setState(() => _acceptedFee = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
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
