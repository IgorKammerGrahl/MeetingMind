import 'processing_status.dart';

class Meeting {
  final String id;
  final ProcessingStatus status;
  final MeetingKnowledge? knowledge;
  final String? error;

  const Meeting({
    required this.id,
    required this.status,
    this.knowledge,
    this.error,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    final rawError = json['error'] as String?;
    final rawKnowledge = json['knowledge'];
    return Meeting(
      id: json['id'] as String,
      status: ProcessingStatus.fromString(json['status'] as String),
      knowledge: rawKnowledge == null
          ? null
          : MeetingKnowledge.fromJson(rawKnowledge as Map<String, dynamic>),
      error: (rawError == null || rawError.isEmpty) ? null : rawError,
    );
  }
}

/// Compact history row from GET /meetings — no knowledge payload.
class MeetingSummary {
  final String id;
  final ProcessingStatus status;
  final String title;
  final DateTime createdAt;

  const MeetingSummary({
    required this.id,
    required this.status,
    required this.title,
    required this.createdAt,
  });

  factory MeetingSummary.fromJson(Map<String, dynamic> json) {
    return MeetingSummary(
      id: json['id'] as String,
      status: ProcessingStatus.fromString(json['status'] as String),
      title: json['title'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class MeetingKnowledge {
  final String title;
  final String summary;
  final String meetingType;
  final List<Task> tasks;

  const MeetingKnowledge({
    required this.title,
    required this.summary,
    required this.meetingType,
    required this.tasks,
  });

  factory MeetingKnowledge.fromJson(Map<String, dynamic> json) {
    final rawTasks = (json['tasks'] as List?) ?? const [];
    return MeetingKnowledge(
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      meetingType: json['meeting_type'] as String? ?? '',
      tasks: rawTasks
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Task {
  final String responsible;
  final String task;
  final String deadline;
  final String priority;

  const Task({
    required this.responsible,
    required this.task,
    required this.deadline,
    required this.priority,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      responsible: json['responsible'] as String? ?? '',
      task: json['task'] as String? ?? '',
      deadline: json['deadline'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
    );
  }
}
