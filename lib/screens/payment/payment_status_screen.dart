// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/payment.dart';
import '../../models/cube_booking.dart';
import '../../services/payment_service.dart';
import '../cubes/booking_receipt_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String paymentId;
  final String houseName;
  final int cubeNumber;

  const PaymentStatusScreen({
    super.key,
    required this.paymentId,
    required this.houseName,
    required this.cubeNumber,
  });

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  StreamSubscription? _paymentSub;
  Payment? _payment;
  bool _timedOut = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _startTime = DateTime.now();
    _listenToPayment();

    // Timeout after 5 minutes
    Timer(const Duration(minutes: 5), () {
      if (mounted && _payment?.status == PaymentStatus.pending) {
        setState(() => _timedOut = true);
      }
    });
  }

  void _listenToPayment() {
    _paymentSub = PaymentService().watchPayment(widget.paymentId).listen((
      payment,
    ) {
      if (!mounted) return;
      setState(() => _payment = payment);

      if (payment != null && payment.status == PaymentStatus.completed) {
        _navigateToReceipt();
      }
    });
  }

  void _navigateToReceipt() {
    _paymentSub?.cancel();
    // Fetch the booking to show receipt
    FirebaseFirestore.instance
        .collection('cube_bookings')
        .doc(payment?.bookingId ?? '')
        .get()
        .then((doc) {
          if (!mounted) return;
          if (doc.exists) {
            final booking = CubeBooking.fromJson(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BookingReceiptScreen(booking: booking),
              ),
            );
          }
        });
  }

  Payment? get payment => _payment;

  @override
  void dispose() {
    _pulseController.dispose();
    _paymentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = payment?.status == PaymentStatus.completed;
    final isFailed = payment?.status == PaymentStatus.failed;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated status indicator
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 1.0 + (_pulseController.value * 0.1);
                      return Transform.scale(
                        scale: isCompleted || isFailed ? 1.0 : scale,
                        child: child,
                      );
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? Colors.green.shade100
                            : isFailed
                            ? Colors.red.shade100
                            : Colors.orange.shade100,
                      ),
                      child: Icon(
                        isCompleted
                            ? Icons.check_circle_outline
                            : isFailed
                            ? Icons.error_outline
                            : Icons.hourglass_top,
                        size: 50,
                        color: isCompleted
                            ? Colors.green
                            : isFailed
                            ? Colors.red
                            : Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Status text
                  Text(
                    isCompleted
                        ? 'Payment Successful!'
                        : isFailed
                        ? 'Payment Failed'
                        : _timedOut
                        ? 'Taking longer than expected'
                        : 'Processing Payment...',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? Colors.green.shade700
                          : isFailed
                          ? Colors.red.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    isCompleted
                        ? 'Your cubicle has been confirmed.'
                        : isFailed
                        ? (payment?.failureReason ??
                              'Payment could not be completed. Please try again.')
                        : _timedOut
                        ? 'The payment is still being processed. You will receive a notification once it completes.'
                        : 'Please wait while we confirm your payment.\nDo not close this screen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),

                  if (payment != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _InfoRow('Method', payment!.methodLabel),
                          const SizedBox(height: 6),
                          _InfoRow(
                            'Amount',
                            'KES ${payment!.amount.toStringAsFixed(0)}',
                          ),
                          if (payment!.phoneNumber != null) ...[
                            const SizedBox(height: 6),
                            _InfoRow('Phone', payment!.phoneNumber!),
                          ],
                          const SizedBox(height: 6),
                          _InfoRow('Status', payment!.statusLabel),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  if (isFailed || _timedOut)
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    )
                  else if (!isCompleted)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
