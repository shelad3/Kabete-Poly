import '../utils/term_utils.dart';

class CubeBooking {
  final String id;
  final String studentId;
  final String studentName;
  final String regNo;
  final String cubeId;
  final String houseId;
  final String houseName;
  final int cubeNumber;
  final int term;
  final int year;
  final String status; // pending, confirmed, checked_in, completed, cancelled
  final String paymentStatus; // unpaid, paid

  CubeBooking({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.regNo,
    required this.cubeId,
    required this.houseId,
    required this.houseName,
    required this.cubeNumber,
    required this.term,
    required this.year,
    this.status = 'pending',
    this.paymentStatus = 'unpaid',
  });

  String get cubeLabel => 'Cube $cubeNumber';
  String get termLabel => 'Term $term';

  factory CubeBooking.fromJson(Map<String, dynamic> json, String docId) => CubeBooking(
    id: docId,
    studentId: json['studentId'] as String? ?? '',
    studentName: json['studentName'] as String? ?? '',
    regNo: json['regNo'] as String? ?? '',
    cubeId: json['cubeId'] as String? ?? '',
    houseId: json['houseId'] as String? ?? '',
    houseName: json['houseName'] as String? ?? '',
    cubeNumber: (json['cubeNumber'] as num?)?.toInt() ?? 0,
    term: (json['term'] as num?)?.toInt() ?? TermUtils.getCurrentTerm(),
    year: (json['year'] as num?)?.toInt() ?? TermUtils.getCurrentYear(),
    status: json['status'] as String? ?? 'pending',
    paymentStatus: json['paymentStatus'] as String? ?? 'unpaid',
  );

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'studentName': studentName,
    'regNo': regNo,
    'cubeId': cubeId,
    'houseId': houseId,
    'houseName': houseName,
    'cubeNumber': cubeNumber,
    'term': term,
    'year': year,
    'status': status,
    'paymentStatus': paymentStatus,
  };
}
