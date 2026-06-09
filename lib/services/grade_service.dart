import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grade_record.dart';

class GradeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _grades => _firestore.collection('grades');

  Stream<List<GradeRecord>> getGradesForClass(String classId, {String? term, String? academicYear}) {
    Query query = _grades.where('classId', isEqualTo: classId);
    if (term != null) query = query.where('term', isEqualTo: term);
    if (academicYear != null) query = query.where('academicYear', isEqualTo: academicYear);
    return query.snapshots().map((snap) =>
      snap.docs.map((doc) => GradeRecord.fromJson(doc.data() as Map<String, dynamic>, doc.id)).toList()
    );
  }

  Stream<List<GradeRecord>> getGradesForStudent(String studentId) {
    return _grades.where('studentId', isEqualTo: studentId).snapshots().map((snap) =>
      snap.docs.map((doc) => GradeRecord.fromJson(doc.data() as Map<String, dynamic>, doc.id)).toList()
    );
  }

  Future<void> saveGrade(GradeRecord grade) async {
    await _grades.doc(grade.id).set(grade.toJson());
  }

  Future<void> deleteGrade(String gradeId) async {
    await _grades.doc(gradeId).delete();
  }

  Future<String> createGrade(GradeRecord grade) async {
    final doc = await _grades.add(grade.toJson());
    return doc.id;
  }

  Future<Map<String, double>> getClassStandings(String classId, {String? term, String? academicYear}) async {
    final grades = await getGradesForClass(classId, term: term, academicYear: academicYear).first;
    final Map<String, List<double>> studentTotals = {};
    for (final g in grades) {
      studentTotals.putIfAbsent(g.studentId, () => []);
      studentTotals[g.studentId]!.add(g.percentage);
    }
    return studentTotals.map((k, v) => MapEntry(k, v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length));
  }
}
