class Cube {
  final String id;
  final String houseId;
  final String houseName;
  final int cubeNumber;
  final int maxOccupancy;
  final String? side; // 'left' or 'right' for 6+6 layout
  final bool isActive;

  Cube({
    required this.id,
    required this.houseId,
    required this.houseName,
    required this.cubeNumber,
    this.maxOccupancy = 4,
    this.side,
    this.isActive = true,
  });

  String get label => 'Cube $cubeNumber';

  factory Cube.fromJson(Map<String, dynamic> json, String docId) => Cube(
    id: docId,
    houseId: json['houseId'] as String? ?? '',
    houseName: json['houseName'] as String? ?? '',
    cubeNumber: (json['cubeNumber'] as num?)?.toInt() ?? 1,
    maxOccupancy: (json['maxOccupancy'] as num?)?.toInt() ?? 4,
    side: json['side'] as String?,
    isActive: json['isActive'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'houseId': houseId,
    'houseName': houseName,
    'cubeNumber': cubeNumber,
    'maxOccupancy': maxOccupancy,
    if (side != null) 'side': side,
    'isActive': isActive,
  };
}
