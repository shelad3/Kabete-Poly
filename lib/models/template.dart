class LessonTemplate {
  final String id;
  final String createdBy;
  final String name;
  final String topic;
  final String subtopic;
  final String teacher;
  final String content;
  final String summary;
  final String report;
  final String nb1;
  final String nb2;

  LessonTemplate({
    required this.id,
    required this.createdBy,
    required this.name,
    required this.topic,
    required this.subtopic,
    required this.teacher,
    required this.content,
    required this.summary,
    required this.report,
    required this.nb1,
    required this.nb2,
  });

  factory LessonTemplate.fromJson(Map<String, dynamic> json, String docId) {
    return LessonTemplate(
      id: docId,
      createdBy: json['createdBy'] ?? '',
      name: json['name'] ?? '',
      topic: json['topic'] ?? '',
      subtopic: json['subtopic'] ?? '',
      teacher: json['teacher'] ?? '',
      content: json['content'] ?? '',
      summary: json['summary'] ?? '',
      report: json['report'] ?? '',
      nb1: json['nb1'] ?? '',
      nb2: json['nb2'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'createdBy': createdBy,
    'name': name,
    'topic': topic,
    'subtopic': subtopic,
    'teacher': teacher,
    'content': content,
    'summary': summary,
    'report': report,
    'nb1': nb1,
    'nb2': nb2,
  };
}

class ScheduleTemplate {
  final String id;
  final String createdBy;
  final String name;
  final String subject;
  final String room;
  final bool isPractical;

  ScheduleTemplate({
    required this.id,
    required this.createdBy,
    required this.name,
    required this.subject,
    required this.room,
    required this.isPractical,
  });

  factory ScheduleTemplate.fromJson(Map<String, dynamic> json, String docId) {
    return ScheduleTemplate(
      id: docId,
      createdBy: json['createdBy'] ?? '',
      name: json['name'] ?? '',
      subject: json['subject'] ?? '',
      room: json['room'] ?? '',
      isPractical: json['isPractical'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'createdBy': createdBy,
    'name': name,
    'subject': subject,
    'room': room,
    'isPractical': isPractical,
  };
}
