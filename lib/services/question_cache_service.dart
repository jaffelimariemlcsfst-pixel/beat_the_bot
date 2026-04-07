import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/question.dart';
import 'ai_service.dart';

class AllKeysExhaustedException implements Exception {
  const AllKeysExhaustedException();
}

class QuestionCacheService {
  static const String _supabaseUrl = 'https://yftqbbrocytsggrmuyjj.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlmdHFiYnJvY3l0c2dncm11eWpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NjYwNzUsImV4cCI6MjA5MDA0MjA3NX0.95DFA5l1tQlz_HLECdPyq-6jYRBA8fl-oDHVl_6NF9Q';
  static const String _table = 'questions';

  final AiService _ai = AiService();
  final Random _rng = Random();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'apikey': _anonKey,
        'Authorization': 'Bearer $_anonKey',
      };

  // ─── Main entry point ────────────────────────────────────────────────────────

  /// Always generates a fresh question from Groq.
  ///
  /// The old approach read from a Supabase cache first, which caused the same
  /// questions to repeat every session because the table fills up quickly and
  /// those cached rows are served back indefinitely (up to used_count < 3).
  ///
  /// Fix: cache reads are removed entirely. Every question is AI-generated fresh.
  /// Generated questions are still saved to Supabase in the background so the
  /// data accumulates for potential future use (analytics, seeding, etc.),
  /// but they are never read back to serve as questions.
  Future<Question> getQuestion({
    required String topic,
    required String answerType,
    List<String> excludePrompts = const [],
  }) async {
    final resolvedType =
        answerType == 'random' ? _randomAnswerType() : answerType;

    // Always generate fresh from Groq — no cache read
    final fresh = await _ai.generateQuestion(
      topic,
      resolvedType,
      excludeQuestions: excludePrompts,
    );

    // Save to Supabase in the background (fire and forget — not critical)
    _saveToCache(fresh);

    return fresh;
  }

  // ─── Cache write (background only) ───────────────────────────────────────────

  Future<void> _saveToCache(Question q) async {
    try {
      final body = jsonEncode({
        'topic': q.topic.toLowerCase(),
        'answer_type': q.answerType,
        'prompt': q.prompt,
        'correct_answer': q.correctAnswer,
        'choices': q.choices ?? [],
        'image_options': q.imageOptions ?? [],
        'used_count': 0,
      });

      await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/$_table'),
        headers: {
          ..._headers,
          'Prefer': 'resolution=ignore-duplicates,return=minimal',
        },
        body: body,
      );
    } catch (_) {
      // Not critical — question was already returned to the player
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _randomAnswerType() {
    const types = ['write', 'multiple_choice', 'draw', 'pick_image'];
    return types[_rng.nextInt(types.length)];
  }
}
