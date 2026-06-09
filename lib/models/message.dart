class ChatMessage {
  final String id;
  final String classId;
  final String channelId; // Links to ForumChannel
  final String senderId; // Firebase Auth UID for rule enforcement
  final String senderName;
  final String senderAvatarUrl;
  final String text;
  final String? imageUrl;
  final DateTime timestamp;
  final List<ChatReaction> reactions;

  ChatMessage({
    required this.id,
    required this.classId,
    this.channelId = 'public-chat',
    this.senderId = '',
    required this.senderName,
    required this.senderAvatarUrl,
    required this.text,
    this.imageUrl,
    required this.timestamp,
    this.reactions = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String documentId) {
    return ChatMessage(
      id: documentId,
      classId: json['classId'] ?? 'General',
      channelId: json['channelId'] ?? 'public-chat',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Unknown',
      senderAvatarUrl: json['senderAvatarUrl'] ?? '',
      text: json['text'] ?? '',
      imageUrl: json['imageUrl'],
      timestamp: json['timestamp'] != null 
          ? (json['timestamp'] is String
              ? DateTime.parse(json['timestamp'])
              : (json['timestamp'] as dynamic).toDate() as DateTime)
          : DateTime.now(),
      reactions: (json['reactions'] as List<dynamic>?)
          ?.map((e) => ChatReaction.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'channelId': channelId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'text': text,
      'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
      'reactions': reactions.map((e) => e.toJson()).toList(),
    };
  }
}

class ChatReaction {
  final String userId;
  final String emoji;

  ChatReaction({required this.userId, required this.emoji});

  factory ChatReaction.fromJson(Map<String, dynamic> json) {
    return ChatReaction(
      userId: json['userId'] ?? '',
      emoji: json['emoji'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'emoji': emoji,
    };
  }
}
