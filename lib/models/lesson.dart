class Lesson {
  final String id;
  final String classId; // Targets a specific class cohort (e.g. "EET 600 M24")
  final String topic;
  final String subtopic;
  final String teacher;
  final String? imageUrl;
  final String content;
  final String summary;
  final List<String> practicalPictures;
  final String report;
  final String nb1;
  final String nb2;
  final DateTime date;
  final String? attachmentUrl;
  final String? attachmentName;

  Lesson({
    required this.id,
    required this.classId,
    required this.topic,
    required this.subtopic,
    required this.teacher,
    this.imageUrl,
    required this.content,
    required this.summary,
    required this.practicalPictures,
    required this.report,
    required this.nb1,
    required this.nb2,
    required this.date,
    this.attachmentUrl,
    this.attachmentName,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id'],
      classId: json['classId'] ?? 'General',
      topic: json['topic'],
      subtopic: json['subtopic'],
      teacher: json['teacher'],
      imageUrl: json['imageUrl'],
      content: json['content'] ?? '',
      summary: json['summary'] ?? '',
      practicalPictures: List<String>.from(json['practicalPictures'] ?? []),
      report: json['report'] ?? '',
      nb1: json['nb1'] ?? '',
      nb2: json['nb2'] ?? '',
      date: json['date'] != null
          ? (json['date'] is String
              ? DateTime.parse(json['date'])
              : (json['date'] as dynamic).toDate() as DateTime)
          : DateTime.now(),
      attachmentUrl: json['attachmentUrl'],
      attachmentName: json['attachmentName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'classId': classId,
      'topic': topic,
      'subtopic': subtopic,
      'teacher': teacher,
      'imageUrl': imageUrl,
      'content': content,
      'summary': summary,
      'practicalPictures': practicalPictures,
      'report': report,
      'nb1': nb1,
      'nb2': nb2,
      'date': date.toIso8601String(),
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
    };
  }
}
