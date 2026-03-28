class Session {
  final String id;
  final String userId;
  final String topic;
  final String answerType;
  final int score;
  final int timeTaken;
  final DateTime createdAt;

  Session({
    required this.id,
    required this.userId,
    required this.topic,
    required this.answerType,
    required this.score,
    required this.timeTaken,
    required this.createdAt,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      topic: json['topic'] as String,
      answerType: json['answer_type'] as String,
      score: json['score'] as int,
      timeTaken: json['time_taken'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'topic': topic,
        'answer_type': answerType,
        'score': score,
        'time_taken': timeTaken,
        'created_at': createdAt.toIso8601String(),
      };
}
