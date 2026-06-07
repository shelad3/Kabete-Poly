import 'package:cloud_firestore/cloud_firestore.dart';

class HelpRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String title;
  final String message;
  final DateTime timestamp;
  final String status; // pending, resolved
  final String? resolvedBy;
  final DateTime? resolvedAt;

  HelpRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.title,
    required this.message,
    required this.timestamp,
    this.status = 'pending',
    this.resolvedBy,
    this.resolvedAt,
  });

  factory HelpRequest.fromJson(Map<String, dynamic> json, String docId) {
    return HelpRequest(
      id: docId,
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userEmail: json['userEmail'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: json['status'] ?? 'pending',
      resolvedBy: json['resolvedBy'],
      resolvedAt: (json['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userName': userName,
    'userEmail': userEmail,
    'title': title,
    'message': message,
    'timestamp': timestamp,
    'status': status,
    'resolvedBy': resolvedBy,
    'resolvedAt': resolvedAt,
  };
}

class ErrorReport {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String title;
  final String message;
  final String appVersion;
  final DateTime timestamp;
  final String status; // pending, acknowledged, resolved

  ErrorReport({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.title,
    required this.message,
    required this.appVersion,
    required this.timestamp,
    this.status = 'pending',
  });

  factory ErrorReport.fromJson(Map<String, dynamic> json, String docId) {
    return ErrorReport(
      id: docId,
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userEmail: json['userEmail'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      appVersion: json['appVersion'] ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userName': userName,
    'userEmail': userEmail,
    'title': title,
    'message': message,
    'appVersion': appVersion,
    'timestamp': timestamp,
    'status': status,
  };
}

class AppFeedback {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String message;
  final int? rating;
  final DateTime timestamp;
  final String status; // new, read

  AppFeedback({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.message,
    this.rating,
    required this.timestamp,
    this.status = 'new',
  });

  factory AppFeedback.fromJson(Map<String, dynamic> json, String docId) {
    return AppFeedback(
      id: docId,
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userEmail: json['userEmail'] ?? '',
      message: json['message'] ?? '',
      rating: json['rating'],
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: json['status'] ?? 'new',
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'userName': userName,
    'userEmail': userEmail,
    'message': message,
    'rating': rating,
    'timestamp': timestamp,
    'status': status,
  };
}

class Alert {
  final String id;
  final String title;
  final String message;
  final String type; // info, warning, class_update
  final String targetType; // all, class, user
  final String? targetId;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final List<String> readBy;

  Alert({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.targetType,
    this.targetId,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.readBy = const [],
  });

  factory Alert.fromJson(Map<String, dynamic> json, String docId) {
    return Alert(
      id: docId,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      targetType: json['targetType'] ?? 'all',
      targetId: json['targetId'],
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readBy: List<String>.from(json['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'message': message,
    'type': type,
    'targetType': targetType,
    'targetId': targetId,
    'senderId': senderId,
    'senderName': senderName,
    'timestamp': timestamp,
    'readBy': readBy,
  };
}
