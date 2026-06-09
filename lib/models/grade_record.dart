class GradeRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String subjectName;
  final String classId;
  final String term;
  final String academicYear;
  final double cat1Score;
  final double cat1Max;
  final double cat2Score;
  final double cat2Max;
  final double examScore;
  final double examMax;
  final String teacherId;
  final String teacherName;
  final String? comments;
  final DateTime createdAt;

  GradeRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.subjectName,
    required this.classId,
    required this.term,
    required this.academicYear,
    this.cat1Score = 0,
    this.cat1Max = 30,
    this.cat2Score = 0,
    this.cat2Max = 30,
    this.examScore = 0,
    this.examMax = 40,
    required this.teacherId,
    required this.teacherName,
    this.comments,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalScore => cat1Score + cat2Score + examScore;
  double get totalMax => cat1Max + cat2Max + examMax;
  double get percentage => totalMax > 0 ? (totalScore / totalMax) * 100 : 0;

  String get grade {
    final pct = percentage;
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    return 'E';
  }

  factory GradeRecord.fromJson(Map<String, dynamic> json, String docId) => GradeRecord(
    id: docId,
    studentId: json['studentId'] as String? ?? '',
    studentName: json['studentName'] as String? ?? '',
    subjectName: json['subjectName'] as String? ?? '',
    classId: json['classId'] as String? ?? '',
    term: json['term'] as String? ?? '',
    academicYear: json['academicYear'] as String? ?? '',
    cat1Score: (json['cat1Score'] as num? ?? 0).toDouble(),
    cat1Max: (json['cat1Max'] as num? ?? 30).toDouble(),
    cat2Score: (json['cat2Score'] as num? ?? 0).toDouble(),
    cat2Max: (json['cat2Max'] as num? ?? 30).toDouble(),
    examScore: (json['examScore'] as num? ?? 0).toDouble(),
    examMax: (json['examMax'] as num? ?? 40).toDouble(),
    teacherId: json['teacherId'] as String? ?? '',
    teacherName: json['teacherName'] as String? ?? '',
    comments: json['comments'] as String?,
    createdAt: (json['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'studentName': studentName,
    'subjectName': subjectName,
    'classId': classId,
    'term': term,
    'academicYear': academicYear,
    'cat1Score': cat1Score,
    'cat1Max': cat1Max,
    'cat2Score': cat2Score,
    'cat2Max': cat2Max,
    'examScore': examScore,
    'examMax': examMax,
    'teacherId': teacherId,
    'teacherName': teacherName,
    'comments': comments,
    'createdAt': createdAt,
  };
}
