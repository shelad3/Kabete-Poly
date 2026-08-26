// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/payment.dart';
import '../../services/payment_service.dart';
import '../../services/auth_provider.dart';
import 'payment_status_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String bookingId;
  final String houseName;
  final int cubeNumber;

  const PaymentMethodScreen({
    super.key,
    required this.bookingId,
    required this.houseName,
    required this.cubeNumber,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  PaymentMethod _selectedMethod = PaymentMethod.mpesa;
  final _phoneController = TextEditingController(text: '254');
  bool _isProcessing = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    if (_selectedMethod == PaymentMethod.mpesa ||
        _selectedMethod == PaymentMethod.airtel) {
      final phone = _phoneController.text.trim();
      if (phone.length < 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid phone number')),
        );
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final userId = context.read<AuthProvider>().currentUserId;
      final payment = await PaymentService().initiatePayment(
        bookingId: widget.bookingId,
        studentId: userId,
        amount: PaymentService.cubeBookingAmount,
        method: _selectedMethod,
        phoneNumber: _selectedMethod != PaymentMethod.card
            ? _phoneController.text.trim()
            : null,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentStatusScreen(
            paymentId: payment.id,
            houseName: widget.houseName,
            cubeNumber: widget.cubeNumber,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Booking Summary',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.houseName} — Cube ${widget.cubeNumber}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'KES ${PaymentService.cubeBookingAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Select Payment Method',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // M-Pesa
            _PaymentOption(
              icon: Icons.phone_android,
              title: 'M-Pesa',
              subtitle: 'Pay via Safaricom M-Pesa STK Push',
              color: Colors.green,
              isSelected: _selectedMethod == PaymentMethod.mpesa,
              onTap: () =>
                  setState(() => _selectedMethod = PaymentMethod.mpesa),
            ),
            const SizedBox(height: 8),

            // Airtel Money
            _PaymentOption(
              icon: Icons.phone,
              title: 'Airtel Money',
              subtitle: 'Pay via Airtel Money',
              color: Colors.red,
              isSelected: _selectedMethod == PaymentMethod.airtel,
              onTap: () =>
                  setState(() => _selectedMethod = PaymentMethod.airtel),
            ),
            const SizedBox(height: 8),

            // Card
            _PaymentOption(
              icon: Icons.credit_card,
              title: 'Card',
              subtitle: 'Debit or Credit Card',
              color: Theme.of(context).colorScheme.primary,
              isSelected: _selectedMethod == PaymentMethod.card,
              onTap: () => setState(() => _selectedMethod = PaymentMethod.card),
            ),
            // Phone number input for mobile money
            if (_selectedMethod == PaymentMethod.mpesa ||
                _selectedMethod == PaymentMethod.airtel) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '254XXXXXXXXX',
                  prefixIcon: const Icon(Icons.phone),
                  border: const OutlineInputBorder(),
                  helperText: _selectedMethod == PaymentMethod.mpesa
                      ? 'You will receive an STK push on this number'
                      : 'Enter your Airtel Money number',
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Pay button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isProcessing ? null : _proceed,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Pay KES ${PaymentService.cubeBookingAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Payment is processed securely. Your cubicle will be confirmed automatically upon successful payment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? color
              : Theme.of(context).colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check_circle, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
