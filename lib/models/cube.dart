class Cube {
  final String id;
  final String roomName;
  final String label;
  final bool isActive;

  Cube({
    required this.id,
    required this.roomName,
    required this.label,
    this.isActive = true,
  });

  factory Cube.fromJson(Map<String, dynamic> json, String docId) => Cube(
    id: docId,
    roomName: json['roomName'] as String? ?? '',
    label: json['label'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'roomName': roomName,
    'label': label,
    'isActive': isActive,
  };
}
