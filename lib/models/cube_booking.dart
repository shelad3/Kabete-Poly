class CubeBooking {
  final String id;
  final String studentId;
  final String studentName;
  final String regNo;
  final String cubeId;
  final String roomName;
  final String cubeLabel;
  final DateTime date;
  final String startTime;  // e.g. "08:00"
  final String endTime;    // e.g. "10:00"
  final String status;     // pending, confirmed, checked_in, completed, cancelled

  CubeBooking({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.regNo,
    required this.cubeId,
    required this.roomName,
    required this.cubeLabel,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.status = 'pending',
  });

  double get durationHours {
    final start = int.tryParse(startTime.split(':')[0]) ?? 0;
    final end = int.tryParse(endTime.split(':')[0]) ?? 0;
    return (end - start).toDouble();
  }

  factory CubeBooking.fromJson(Map<String, dynamic> json, String docId) => CubeBooking(
    id: docId,
    studentId: json['studentId'] as String? ?? '',
    studentName: json['studentName'] as String? ?? '',
    regNo: json['regNo'] as String? ?? '',
    cubeId: json['cubeId'] as String? ?? '',
    roomName: json['roomName'] as String? ?? '',
    cubeLabel: json['cubeLabel'] as String? ?? '',
    date: (json['date'] as dynamic)?.toDate() ?? DateTime.now(),
    startTime: json['startTime'] as String? ?? '08:00',
    endTime: json['endTime'] as String? ?? '10:00',
    status: json['status'] as String? ?? 'pending',
  );

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'studentName': studentName,
    'regNo': regNo,
    'cubeId': cubeId,
    'roomName': roomName,
    'cubeLabel': cubeLabel,
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
    'status': status,
  };
}
