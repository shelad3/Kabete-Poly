class Question {
  final String id;
  final String quizId;
  final String text;
  final List<String> options;
  final int correctIndex;
  final int points;

  Question({
    required this.id,
    required this.quizId,
    required this.text,
    required this.options,
    required this.correctIndex,
    this.points = 1,
  });

  factory Question.fromJson(Map<String, dynamic> json, String docId) {
    return Question(
      id: docId,
      quizId: json['quizId'] ?? '',
      text: json['text'] ?? '',
      options: List<String>.from(json['options'] ?? ['', '', '', '']),
      correctIndex: json['correctIndex'] ?? 0,
      points: json['points'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quizId': quizId,
      'text': text,
      'options': options,
      'correctIndex': correctIndex,
      'points': points,
    };
  }
}
