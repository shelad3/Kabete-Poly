import 'dart:collection';

class AssessmentEntry {
  final double score;
  final double max;

  const AssessmentEntry({this.score = 0, this.max = 30});

  double get percentage => max > 0 ? (score / max) * 100 : 0;

  Map<String, dynamic> toJson() => {'score': score, 'max': max};

  factory AssessmentEntry.fromJson(Map<String, dynamic> json) => AssessmentEntry(
    score: (json['score'] as num? ?? 0).toDouble(),
    max: (json['max'] as num? ?? 30).toDouble(),
  );
}

class GradeRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String subjectName;
  final String classId;
  final String term;
  final String academicYear;
  final Map<String, AssessmentEntry> assessments;
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
    Map<String, AssessmentEntry>? assessments,
    required this.teacherId,
    required this.teacherName,
    this.comments,
    DateTime? createdAt,
  })  : assessments = assessments ?? {},
        createdAt = createdAt ?? DateTime.now();

  double get totalScore => assessments.values.fold(0.0, (sum, a) => sum + a.score);
  double get totalMax => assessments.values.fold(0.0, (sum, a) => sum + a.max);
  double get percentage => totalMax > 0 ? (totalScore / totalMax) * 100 : 0;

  String get grade {
    final pct = percentage;
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    return 'E';
  }

  // Backward-compatible getters
  double get cat1Score => assessments['cat1']?.score ?? 0;
  double get cat1Max => assessments['cat1']?.max ?? 30;
  double get cat2Score => assessments['cat2']?.score ?? 0;
  double get cat2Max => assessments['cat2']?.max ?? 30;
  double get examScore => assessments['exam']?.score ?? 0;
  double get examMax => assessments['exam']?.max ?? 100;

  double getScoreFor(String name) => assessments[name]?.score ?? 0;
  double getMaxFor(String name) => assessments[name]?.max ?? 0;

  factory GradeRecord.fromJson(Map<String, dynamic> json, String docId) {
    Map<String, AssessmentEntry> assessments = {};

    // New format: assessments map
    final rawAssessments = json['assessments'] as Map<String, dynamic>?;
    if (rawAssessments != null && rawAssessments.isNotEmpty) {
      rawAssessments.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          assessments[key] = AssessmentEntry.fromJson(val);
        }
      });
    }

    // Backward compat: old fixed fields
    if (assessments.isEmpty) {
      final oldCat1 = (json['cat1Score'] as num? ?? 0).toDouble();
      final oldCat1Max = (json['cat1Max'] as num? ?? 30).toDouble();
      final oldCat2 = (json['cat2Score'] as num? ?? 0).toDouble();
      final oldCat2Max = (json['cat2Max'] as num? ?? 30).toDouble();
      final oldExam = (json['examScore'] as num? ?? 0).toDouble();
      final oldExamMax = (json['examMax'] as num? ?? 40).toDouble();

      if (oldCat1 > 0 || oldCat1Max != 30) assessments['cat1'] = AssessmentEntry(score: oldCat1, max: oldCat1Max);
      if (oldCat2 > 0 || oldCat2Max != 30) assessments['cat2'] = AssessmentEntry(score: oldCat2, max: oldCat2Max);
      if (oldExam > 0 || oldExamMax != 40) assessments['exam'] = AssessmentEntry(score: oldExam, max: oldExamMax);
      // If still empty, add defaults
      if (assessments.isEmpty) {
        assessments['cat1'] = const AssessmentEntry();
        assessments['cat2'] = const AssessmentEntry();
        assessments['exam'] = const AssessmentEntry(max: 100);
      }
    }

    return GradeRecord(
      id: docId,
      studentId: json['studentId'] as String? ?? '',
      studentName: json['studentName'] as String? ?? '',
      subjectName: json['subjectName'] as String? ?? '',
      classId: json['classId'] as String? ?? '',
      term: json['term'] as String? ?? '',
      academicYear: json['academicYear'] as String? ?? '',
      assessments: assessments,
      teacherId: json['teacherId'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      comments: json['comments'] as String?,
      createdAt: (json['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'studentId': studentId,
    'studentName': studentName,
    'subjectName': subjectName,
    'classId': classId,
    'term': term,
    'academicYear': academicYear,
    'assessments': assessments.map((k, v) => MapEntry(k, v.toJson())),
    'teacherId': teacherId,
    'teacherName': teacherName,
    'comments': comments,
    'createdAt': createdAt,
  };
}
