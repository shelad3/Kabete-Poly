import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quiz.dart';
import '../models/question.dart';

class QuizService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<Quiz>> getQuizzesStream(String classId) {
    return _firestore
        .collection('quizzes')
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Quiz.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<Quiz?> getQuiz(String quizId) async {
    final doc = await _firestore.collection('quizzes').doc(quizId).get();
    if (!doc.exists) return null;
    return Quiz.fromJson(doc.data()!, doc.id);
  }

  Future<String> createQuiz(Quiz quiz) async {
    final doc = await _firestore.collection('quizzes').add(quiz.toJson());
    return doc.id;
  }

  Future<void> updateQuiz(String quizId, Map<String, dynamic> data) async {
    await _firestore.collection('quizzes').doc(quizId).update(data);
  }

  Future<void> deleteQuiz(String quizId) async {
    final questions = await _firestore
        .collection('questions')
        .where('quizId', isEqualTo: quizId)
        .get();
    for (final q in questions.docs) {
      await q.reference.delete();
    }
    await _firestore.collection('quizzes').doc(quizId).delete();
  }

  // Questions as a top-level collection (simpler than subcollections)
  Stream<List<Question>> getQuestionsStream(String quizId) {
    return _firestore
        .collection('questions')
        .where('quizId', isEqualTo: quizId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Question.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<List<Question>> getQuestions(String quizId) async {
    final snap = await _firestore
        .collection('questions')
        .where('quizId', isEqualTo: quizId)
        .get();
    return snap.docs
        .map((doc) => Question.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<String> addQuestion(Question question) async {
    final doc = await _firestore.collection('questions').add(question.toJson());
    return doc.id;
  }

  Future<void> updateQuestion(String questionId, Map<String, dynamic> data) async {
    await _firestore.collection('questions').doc(questionId).update(data);
  }

  Future<void> deleteQuestion(String questionId) async {
    await _firestore.collection('questions').doc(questionId).delete();
  }

  // Submissions
  Stream<List<QuizSubmission>> getSubmissionsStream(String quizId) {
    return _firestore
        .collection('quiz_submissions')
        .where('quizId', isEqualTo: quizId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => QuizSubmission.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<bool> hasSubmitted(String quizId, String userId) async {
    final snap = await _firestore
        .collection('quiz_submissions')
        .where('quizId', isEqualTo: quizId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> submitQuiz(QuizSubmission submission) async {
    await _firestore.collection('quiz_submissions').add(submission.toJson());
  }
}
