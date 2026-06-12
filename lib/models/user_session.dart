class UserSession {
  final String id;
  final String userId;
  final String deviceName;
  final String deviceType;
  final String ipAddress;
  final String location;
  final DateTime loginAt;
  final DateTime lastActiveAt;
  final bool isCurrentDevice;

  UserSession({
    required this.id,
    required this.userId,
    required this.deviceName,
    required this.deviceType,
    this.ipAddress = '',
    this.location = '',
    required this.loginAt,
    required this.lastActiveAt,
    this.isCurrentDevice = false,
  });

  factory UserSession.fromJson(Map<String, dynamic> json, String docId) {
    return UserSession(
      id: docId,
      userId: json['userId'] ?? '',
      deviceName: json['deviceName'] ?? 'Unknown Device',
      deviceType: json['deviceType'] ?? 'Unknown',
      ipAddress: json['ipAddress'] ?? '',
      location: json['location'] ?? '',
      loginAt: json['loginAt'] != null
          ? (json['loginAt'] is String
              ? DateTime.parse(json['loginAt'])
              : (json['loginAt'] as dynamic).toDate() as DateTime)
          : DateTime.now(),
      lastActiveAt: json['lastActiveAt'] != null
          ? (json['lastActiveAt'] is String
              ? DateTime.parse(json['lastActiveAt'])
              : (json['lastActiveAt'] as dynamic).toDate() as DateTime)
          : DateTime.now(),
      isCurrentDevice: json['isCurrentDevice'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'deviceName': deviceName,
    'deviceType': deviceType,
    'ipAddress': ipAddress,
    'location': location,
    'loginAt': loginAt.toIso8601String(),
    'lastActiveAt': lastActiveAt.toIso8601String(),
    'isCurrentDevice': isCurrentDevice,
  };
}
