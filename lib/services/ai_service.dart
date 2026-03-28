import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiService {
  static const String _apiUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static String get _apiKey => dotenv.env['GROQ_API_KEY'] ?? '';// ← paste your key
  static const String _model = 'llama-3.3-70b-versatile';

  Future<Question> generateQuestion(
    String topic,
    String answerType, {
    List<String> excludeQuestions = const [],
  }) async {
    final text = await _callGroq(
        _buildGeneratePrompt(topic, answerType, excludeQuestions));
    return _parseQuestion(text, topic, answerType);
  }

  String _buildGeneratePrompt(
      String topic, String answerType, List<String> exclude) {
    final typeInstructions = switch (answerType) {
      'multiple_choice' => '''
Answer type: multiple_choice
Include a "choices" array with exactly 4 options (strings). One must be correct.
Set "correctAnswer" to the exact text of the correct choice.
Leave "imageOptions" as an empty array [].''',
      'pick_image' => '''
Answer type: pick_image
Include an "imageOptions" array with exactly 4 SHORT search keywords (1-3 words each, suitable for image search).
One keyword must represent the correct answer visually.
Set "correctAnswer" to the exact keyword that is correct.
Example imageOptions: ["Eiffel Tower", "Big Ben", "Colosseum", "Sagrada Familia"]
Leave "choices" as an empty array [].''',
      'draw' => '''
Answer type: draw
Ask the user to draw something simple and recognizable.
Set "correctAnswer" to a short description of what a correct drawing looks like.
Leave "choices" and "imageOptions" as empty arrays [].''',
      _ => '''
Answer type: write
Ask a question with a short written answer (1-3 sentences).
Set "correctAnswer" to the ideal answer.
Leave "choices" and "imageOptions" as empty arrays [].''',
    };

    return '''You are generating a quiz question for a mobile game called Beat the Bot.

Topic: $topic
$typeInstructions

Respond ONLY with valid JSON. No markdown, no explanation, no backticks.

{
  "prompt": "The question text",
  "correctAnswer": "The ideal answer",
  "answerType": "$answerType",
  "topic": "$topic",
  "choices": [],
  "imageOptions": []
}

Rules:
- Make it interesting, educational, and moderately difficult.
- The question must be clearly related to: $topic
- Keep the prompt concise (max 20 words).
${exclude.isEmpty ? '' : '\nDo NOT repeat any of these questions:\n${exclude.map((q) => '- $q').join('\n')}\nGenerate a completely different question.'}''';
  }

  Question _parseQuestion(String raw, String topic, String answerType) {
    try {
      final clean =
          raw.replaceAll('```json', '').replaceAll('```', '').trim();
      return Question.fromJson(jsonDecode(clean));
    } catch (_) {
      return _fallbackQuestion(topic, answerType);
    }
  }

  Question _fallbackQuestion(String topic, String answerType) {
    final fallbacks = {
      'science': ['What planet is closest to the Sun?', 'Mercury'],
      'history': ['In what year did World War II end?', '1945'],
      'geography': ['What is the capital of France?', 'Paris'],
      'general': ['How many sides does a hexagon have?', '6'],
      'psychology': [
        'What is the term for learning by observation?',
        'Observational learning'
      ],
      'philosophy': ['Who wrote "The Republic"?', 'Plato'],
      'technology': ['What does CPU stand for?', 'Central Processing Unit'],
      'marketing': ['What does ROI stand for?', 'Return on Investment'],
      'business': ['What does B2B stand for?', 'Business to Business'],
      'design': [
        'What are the three primary colors of light?',
        'Red, Green, Blue'
      ],
    };

    final key = topic.toLowerCase();
    final data = fallbacks[key] ?? ['What is 2 + 2?', '4'];

    return Question(
      prompt: data[0],
      correctAnswer: data[1],
      answerType: answerType,
      topic: topic,
      choices: answerType == 'multiple_choice'
          ? [data[1], 'Option B', 'Option C', 'Option D']
          : null,
    );
  }

  Future<Map<String, dynamic>> judgeAnswer(
    Question question,
    String correct,
    String userAnswer,
  ) async {
    final text =
        await _callGroq(_buildJudgePrompt(question, correct, userAnswer));
    return _parseJudgement(text, correct);
  }

  String _buildJudgePrompt(Question q, String correct, String user) =>
      '''You are the judge for Beat the Bot, a quiz game.

Question: ${q.prompt}
Correct answer: $correct
User's answer: ${user.isEmpty ? '[no answer / time ran out]' : user}

Be generous — accept equivalent answers, synonyms, and partial answers that show understanding.
For draw questions, "[drawing submitted]" always counts as a valid attempt.

Respond ONLY with valid JSON. No markdown, no explanation.

{
  "isCorrect": true or false,
  "feedback": "2-3 sentence encouraging explanation",
  "optimalAnswer": "The best possible answer, written clearly"
}''';

  Map<String, dynamic> _parseJudgement(String raw, String correct) {
    try {
      final clean =
          raw.replaceAll('```json', '').replaceAll('```', '').trim();
      final j = jsonDecode(clean) as Map<String, dynamic>;
      return {
        'isCorrect': j['isCorrect'] ?? false,
        'feedback': j['feedback'] ?? 'No feedback available.',
        'optimalAnswer': j['optimalAnswer'] ?? correct,
      };
    } catch (_) {
      return {
        'isCorrect': false,
        'feedback': 'Could not evaluate your answer. Try again!',
        'optimalAnswer': correct,
      };
    }
  }

  Future<String> _callGroq(String prompt) async {
    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'max_tokens': 512,
        'temperature': 0.8,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are a quiz question generator. Always respond with valid JSON only.',
          },
          {
            'role': 'user',
            'content': prompt,
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Groq API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }
}