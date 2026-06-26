class Cube {
  final String id;
  final String houseName;
  final String label;
  final bool isActive;

  Cube({
    required this.id,
    required this.houseName,
    required this.label,
    this.isActive = true,
  });

  factory Cube.fromJson(Map<String, dynamic> json, String docId) => Cube(
    id: docId,
    houseName: json['houseName'] as String? ?? '',
    label: json['label'] as String? ?? '',
    isActive: json['isActive'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'houseName': houseName,
    'label': label,
    'isActive': isActive,
  };
}
