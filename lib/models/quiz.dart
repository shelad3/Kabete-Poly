class Quiz {
  final String id;
  final String classId;
  final String title;
  final String description;
  final int durationMinutes;
  final List<String> questionIds;
  final String createdBy;
  final DateTime createdAt;
  final bool isPublished;
  final int? maxScore;

  Quiz({
    required this.id,
    required this.classId,
    required this.title,
    this.description = '',
    this.durationMinutes = 10,
    this.questionIds = const [],
    required this.createdBy,
    required this.createdAt,
    this.isPublished = false,
    this.maxScore,
  });

  factory Quiz.fromJson(Map<String, dynamic> json, String docId) {
    return Quiz(
      id: docId,
      classId: json['classId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      durationMinutes: json['durationMinutes'] ?? 10,
      questionIds: List<String>.from(json['questionIds'] ?? []),
      createdBy: json['createdBy'] ?? '',
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] is String
              ? DateTime.parse(json['createdAt'])
              : (json['createdAt'] as dynamic).toDate() as DateTime)
          : DateTime.now(),
      isPublished: json['isPublished'] ?? false,
      maxScore: json['maxScore'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'classId': classId,
      'title': title,
      'description': description,
      'durationMinutes': durationMinutes,
      'questionIds': questionIds,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'isPublished': isPublished,
      'maxScore': maxScore,
    };
  }
}

class QuizSubmission {
  final String id;
  final String quizId;
  final String userId;
  final String studentName;
  final Map<String, String> answers;
  final int score;
  final int total;
  final DateTime submittedAt;

  QuizSubmission({
    required this.id,
    required this.quizId,
    required this.userId,
    required this.studentName,
    required this.answers,
    required this.score,
    required this.total,
    required this.submittedAt,
  });

  factory QuizSubmission.fromJson(Map<String, dynamic> json, String docId) {
    return QuizSubmission(
      id: docId,
      quizId: json['quizId'] ?? '',
      userId: json['userId'] ?? '',
      studentName: json['studentName'] ?? '',
      answers: Map<String, String>.from(json['answers'] ?? {}),
      score: json['score'] ?? 0,
      total: json['total'] ?? 0,
      submittedAt: json['submittedAt'] != null
          ? (json['submittedAt'] is String
              ? DateTime.parse(json['submittedAt'])
              : (json['submittedAt'] as dynamic).toDate() as DateTime)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quizId': quizId,
      'userId': userId,
      'studentName': studentName,
      'answers': answers,
      'score': score,
      'total': total,
      'submittedAt': submittedAt.toIso8601String(),
    };
  }

  double get percentage => total > 0 ? (score / total) * 100 : 0;
}
