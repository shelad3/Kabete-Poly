// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2026 Kabete National Polytechnique

import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMethod { mpesa, airtel, card }

enum PaymentStatus { pending, processing, completed, failed, refunded }

class Payment {
  final String id;
  final String bookingId;
  final String studentId;
  final double amount;
  final String currency;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? phoneNumber;
  final String? checkoutRequestId;
  final String? transactionRef;
  final String? failureReason;
  final DateTime? initiatedAt;
  final DateTime? completedAt;
  final DateTime? failedAt;

  const Payment({
    required this.id,
    required this.bookingId,
    required this.studentId,
    required this.amount,
    this.currency = 'KES',
    required this.method,
    required this.status,
    this.phoneNumber,
    this.checkoutRequestId,
    this.transactionRef,
    this.failureReason,
    this.initiatedAt,
    this.completedAt,
    this.failedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json, String id) {
    return Payment(
      id: id,
      bookingId: json['bookingId'] as String? ?? '',
      studentId: json['studentId'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'KES',
      method: PaymentMethod.values.firstWhere(
        (m) => m.name == json['method'],
        orElse: () => PaymentMethod.mpesa,
      ),
      status: PaymentStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
      phoneNumber: json['phoneNumber'] as String?,
      checkoutRequestId: json['checkoutRequestId'] as String?,
      transactionRef: json['transactionRef'] as String?,
      failureReason: json['failureReason'] as String?,
      initiatedAt: json['initiatedAt'] != null
          ? (json['initiatedAt'] as dynamic).toDate() as DateTime
          : null,
      completedAt: json['completedAt'] != null
          ? (json['completedAt'] as dynamic).toDate() as DateTime
          : null,
      failedAt: json['failedAt'] != null
          ? (json['failedAt'] as dynamic).toDate() as DateTime
          : null,
    );
  }

  factory Payment.fromFirestore(DocumentSnapshot doc) {
    return Payment.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'studentId': studentId,
      'amount': amount,
      'currency': currency,
      'method': method.name,
      'status': status.name,
      'phoneNumber': phoneNumber,
      'checkoutRequestId': checkoutRequestId,
      'transactionRef': transactionRef,
      'failureReason': failureReason,
      'initiatedAt': initiatedAt != null
          ? Timestamp.fromDate(initiatedAt!)
          : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'failedAt': failedAt != null ? Timestamp.fromDate(failedAt!) : null,
    };
  }

  String get methodLabel {
    switch (method) {
      case PaymentMethod.mpesa:
        return 'M-Pesa';
      case PaymentMethod.airtel:
        return 'Airtel Money';
      case PaymentMethod.card:
        return 'Card';
    }
  }

  String get statusLabel {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.processing:
        return 'Processing';
      case PaymentStatus.completed:
        return 'Completed';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }
}
