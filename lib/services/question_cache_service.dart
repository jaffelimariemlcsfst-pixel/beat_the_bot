import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/question.dart';
import 'ai_service.dart';

class AllKeysExhaustedException implements Exception {
  const AllKeysExhaustedException();
}
class QuestionCacheService {
  static const String _supabaseUrl = 'https://yftqbbrocytsggrmuyjj.supabase.co'; // e.g. https://xyz.supabase.co
  static const String _anonKey     = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlmdHFiYnJvY3l0c2dncm11eWpqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NjYwNzUsImV4cCI6MjA5MDA0MjA3NX0.95DFA5l1tQlz_HLECdPyq-6jYRBA8fl-oDHVl_6NF9Q';
  static const String _table       = 'questions';

  // How many cached questions minimum before we just pull from cache
  static const int _minCacheThreshold = 5;

  final AiService _ai = AiService();
  final Random _rng   = Random();

  Map<String, String> get _headers => {
    'Content-Type':  'application/json',
    'apikey':        _anonKey,
    'Authorization': 'Bearer $_anonKey',
  };

  // ─── Main entry point ────────────────────────────────────────────────────────

  /// Returns a question for [topic] + [answerType].
  /// - If answerType is 'random', picks one randomly.
  /// - Checks cache first; generates fresh if cache is thin.
  Future<Question> getQuestion({
    required String topic,
    required String answerType,
    List<String> excludePrompts = const [],
  }) async {
    final resolvedType = answerType == 'random' ? _randomAnswerType() : answerType;

    // 1. Try to get from cache
    final cached = await _fetchFromCache(
      topic: topic,
      answerType: resolvedType,
      excludePrompts: excludePrompts,
    );

    if (cached != null) {
      // 2. Async background: top up cache if getting low (fire and forget)
      _topUpCacheIfNeeded(topic: topic, answerType: resolvedType);
      return cached;
    }

    // 3. Nothing usable in cache — generate fresh
    final fresh = await _ai.generateQuestion(
      topic,
      resolvedType,
      excludeQuestions: excludePrompts,
    );

    // 4. Save it for future players
    await _saveToCache(fresh);

    return fresh;
  }

  // ─── Cache read ──────────────────────────────────────────────────────────────

  Future<Question?> _fetchFromCache({
    required String topic,
    required String answerType,
    required List<String> excludePrompts,
  }) async {
    try {
      final uri = Uri.parse(
        '$_supabaseUrl/rest/v1/$_table'
        '?topic=eq.${Uri.encodeComponent(topic.toLowerCase())}'
        '&answer_type=eq.${Uri.encodeComponent(answerType)}'
        '&order=used_count.asc'   // prefer least-used questions
        '&limit=20',
      );

      final response = await http.get(uri, headers: _headers);
      if (response.statusCode >= 400) return null;

      final rows = jsonDecode(response.body) as List<dynamic>;
      if (rows.isEmpty) return null;

      // Filter out already-asked questions this session
      // WITH THIS
      final available = rows.where((row) {
        final prompt = row['prompt'] as String? ?? '';
        final usedCount = row['used_count'] as int? ?? 0;
        return !excludePrompts.contains(prompt) && usedCount < 3; // ← max 3 uses
      }).toList();

      if (available.isEmpty) return null;

      // Pick a random one from available (weighted toward less-used)
      final row = available[_rng.nextInt(available.length)];
      // Increment used_count (fire and forget)
      _incrementUsedCount(row['id'] as int);

      return _rowToQuestion(row);
    } catch (_) {
      return null; // Cache miss — will generate fresh
    }
  }

  // ─── Cache write ─────────────────────────────────────────────────────────────

  Future<void> _saveToCache(Question q) async {
    try {
      final body = jsonEncode({
        'topic':       q.topic.toLowerCase(),
        'answer_type': q.answerType,
        'prompt':      q.prompt,
        'correct_answer': q.correctAnswer,
        'choices':     q.choices ?? [],
        'image_options': q.imageOptions ?? [],
        'used_count':  0,
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
      // Saving to cache failed — not critical, question was already returned
    }
  }

  Future<void> _incrementUsedCount(int id) async {
    try {
      // Use Supabase RPC to increment atomically
      await http.post(
        Uri.parse('$_supabaseUrl/rest/v1/rpc/increment_question_used'),
        headers: _headers,
        body: jsonEncode({'question_id': id}),
      );
    } catch (_) {
      // Not critical
    }
  }

  // ─── Background top-up ───────────────────────────────────────────────────────

  Future<void> _topUpCacheIfNeeded({
    required String topic,
    required String answerType,
  }) async {
    try {
      final count = await _countCached(topic: topic, answerType: answerType);
      if (count < _minCacheThreshold) {
        // Generate and store 3 new questions silently
        for (int i = 0; i < 3; i++) {
          final q = await _ai.generateQuestion(topic, answerType);
          await _saveToCache(q);
        }
      }
    } catch (_) {
      // Background task — never crash the game
    }
  }

  Future<int> _countCached({
    required String topic,
    required String answerType,
  }) async {
    try {
      final uri = Uri.parse(
        '$_supabaseUrl/rest/v1/$_table'
        '?topic=eq.${Uri.encodeComponent(topic.toLowerCase())}'
        '&answer_type=eq.${Uri.encodeComponent(answerType)}'
        '&select=id',
      );
      final response = await http.get(
        uri,
        headers: {..._headers, 'Prefer': 'count=exact'},
      );
      if (response.statusCode >= 400) return 0;
      final rows = jsonDecode(response.body) as List<dynamic>;
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  String _randomAnswerType() {
    const types = ['write', 'multiple_choice', 'draw', 'pick_image'];
    return types[_rng.nextInt(types.length)];
  }

  Question _rowToQuestion(Map<String, dynamic> row) {
    return Question(
      prompt:        row['prompt'] as String,
      correctAnswer: row['correct_answer'] as String,
      answerType:    row['answer_type'] as String,
      topic:         row['topic'] as String,
      choices: row['answer_type'] == 'multiple_choice'
          ? List<String>.from(row['choices'] ?? [])
          : null,
      imageOptions: row['answer_type'] == 'pick_image'
          ? List<String>.from(row['image_options'] ?? [])
          : null,
    );
  }
}