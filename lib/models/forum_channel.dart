class ForumChannel {
  final String id;
  final String classId;
  final String name;
  final String type; // 'announcement' (admin-only post) or 'chat' (everyone can post)
  final String createdBy;
  final DateTime createdAt;

  ForumChannel({
    required this.id,
    required this.classId,
    required this.name,
    this.type = 'chat',
    required this.createdBy,
    required this.createdAt,
  });

  bool get isAnnouncement => type == 'announcement';

  factory ForumChannel.fromJson(Map<String, dynamic> json, String documentId) {
    return ForumChannel(
      id: documentId,
      classId: json['classId'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? 'chat',
      createdBy: json['createdBy'] ?? '',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String
              ? DateTime.parse(json['createdAt'])
              : (json['createdAt'] as dynamic).toDate() as DateTime)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'name': name,
      'type': type,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
