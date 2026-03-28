class Question {
  final String prompt;
  final String correctAnswer;
  final String answerType;
  final String topic;
  final List<String>? choices;
  final List<String>? imageOptions;
  final String? explanation;

  Question({
    required this.prompt,
    required this.correctAnswer,
    required this.answerType,
    required this.topic,
    this.choices,
    this.imageOptions,
    this.explanation,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        prompt: json['prompt'] as String? ?? 'Unknown question',
        correctAnswer: json['correctAnswer'] as String? ?? '',
        answerType: json['answerType'] as String? ?? 'write',
        topic: json['topic'] as String? ?? 'General Knowledge',
        choices: json['choices'] != null
            ? List<String>.from(json['choices'] as List<dynamic>)
            : null,
        imageOptions: json['imageOptions'] != null
            ? List<String>.from(json['imageOptions'] as List<dynamic>)
            : null,
        explanation: json['explanation'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'prompt': prompt,
        'correctAnswer': correctAnswer,
        'answerType': answerType,
        'topic': topic,
        'choices': choices ?? [],
        'imageOptions': imageOptions ?? [],
        if (explanation != null) 'explanation': explanation,
      };
}
