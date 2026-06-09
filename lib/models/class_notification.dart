// Notification Model

class ClassNotification {
  final String id;
  final String classId; // To target specific cohorts or 'General'
  final String title;
  final String message;
  final String type; // 'canceled', 'event', 'deadline', 'general'
  final DateTime timestamp;

  const ClassNotification({
    required this.id,
    required this.classId,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
  });

  factory ClassNotification.fromJson(Map<String, dynamic> json, String id) {
    return ClassNotification(
      id: id,
      classId: json['classId'] ?? 'General',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'general',
      timestamp: json['timestamp'] != null 
          ? (json['timestamp'] is String
              ? DateTime.parse(json['timestamp'])
              : (json['timestamp'] as dynamic).toDate() as DateTime)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'title': title,
      'message': message,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  // Helper to format "2 hours ago" dynamically
  String get timeAgo {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays == 1) {
      return '1 day ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
