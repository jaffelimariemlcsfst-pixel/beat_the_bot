import 'dart:async';
import 'dart:convert';
import '../services/ai_service.dart';
import '../services/question_cache_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../services/unsplash_service.dart';

class GameScreen extends StatefulWidget {
  final String? topic;
  final String answerType;
  final bool isNewGame;
  final List<String> previousQuestions;
  final int questionsAnswered;
  final int correctAnswersThisSession; // ← ADDED

  const GameScreen({
    super.key,
    this.topic,
    required this.answerType,
    this.isNewGame = true,
    this.previousQuestions = const [],
    this.questionsAnswered = 0,
    this.correctAnswersThisSession = 0, // ← ADDED
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final QuestionCacheService _questionCache = QuestionCacheService();
  final AiService _aiService = AiService();
  final TextEditingController _textCtrl = TextEditingController();
  final UnsplashService _unsplashService = UnsplashService();

  Question? _question;
  bool _loading = true;
  bool _submitting = false;

  _ErrorKind? _errorKind;

  int _timeLeft = 60;
  Timer? _timer;
  int _selectedChoice = -1;
  String _resolvedAnswerType = 'write';
  final List<String> _askedQuestions = [];
  List<List<Offset?>> _strokes = [];
  List<String?> _imageUrls = [];

  late int _questionsAnswered;

  int _correctAnswersThisSession = 0;
  static const int _streakThreshold = 5;

  late int _levelAtSessionStart;
  int _sessionXpEarned = 0;

  @override
  void initState() {
    super.initState();
    _questionsAnswered = widget.questionsAnswered;
    _correctAnswersThisSession = widget.correctAnswersThisSession; // ← ADDED
    _askedQuestions.addAll(widget.previousQuestions);
    _levelAtSessionStart = context.read<UserProvider>().progress.level;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isNewGame) {
        context.read<GameProvider>().startSession();
        _levelAtSessionStart = context.read<UserProvider>().progress.level;
      }
      _loadQuestion();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timeLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        t.cancel();
        _submitAnswer('__timeout__');
      }
    });
  }

  Future<void> _loadQuestion() async {
    setState(() {
      _loading = true;
      _errorKind = null;
      _selectedChoice = -1;
      _textCtrl.clear();
      _strokes = [];
      _imageUrls = [];
    });

    try {
      final type =
          widget.answerType == 'random' ? _randomType() : widget.answerType;
      setState(() => _resolvedAnswerType = type);

      final q = await _questionCache.getQuestion(
        topic: widget.topic ?? 'general',
        answerType: type,
        excludePrompts: _askedQuestions,
      );
      _askedQuestions.add(q.prompt);

      if (!mounted) return;
      setState(() {
        _question = q;
        _loading = false;
      });

      if (type == 'pick_image' &&
          q.imageOptions != null &&
          q.imageOptions!.isNotEmpty) {
        final urls =
            await _unsplashService.fetchImagesForOptions(q.imageOptions!);
        if (mounted) setState(() => _imageUrls = urls);
      }

      _startTimer();
    } on AllKeysExhaustedException {
      if (!mounted) return;
      setState(() {
        _errorKind = _ErrorKind.allKeysExhausted;
        _loading = false;
      });
    } on GroqException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorKind =
            e.isRateLimit ? _ErrorKind.rateLimited : _ErrorKind.serverError;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorKind = _ErrorKind.unknown;
        _loading = false;
      });
    }
  }

  String _randomType() {
    final types = ['write', 'multiple_choice', 'pick_image']..shuffle();
    return types.first;
  }

  Future<void> _submitAnswer(String answer) async {
    if (_submitting || _question == null) return;
    final capturedTimeLeft = _timeLeft;
    _timer?.cancel();
    setState(() => _submitting = true);

    final isTimeout = answer == '__timeout__';

    try {
      final result = await _aiService.judgeAnswer(
          _question!, _question!.correctAnswer, answer);
      if (!mounted) return;

      final gp = context.read<GameProvider>();
      final up = context.read<UserProvider>();

      final isCorrect = result['isCorrect'] == true;

      if (isCorrect) {
        gp.addScore(10, timeLeft: capturedTimeLeft);
        up.addXp(20);
        _sessionXpEarned += 20;
        setState(() => _correctAnswersThisSession++);
      } else {
        gp.loseLife();
      }

      _questionsAnswered++;
      gp.advanceRound();

      final gameOver = gp.lives <= 0;

      if (gameOver) {
        if (_correctAnswersThisSession >= _streakThreshold) {
          up.recordSessionComplete();
        }
        up.updateHighScore(gp.score);
      }

      final levelsGained = up.progress.level - _levelAtSessionStart;

      if (isTimeout && !gameOver && mounted) {
        setState(() => _submitting = false);
        final keepPlaying = await _showTimeoutDialog();
        if (!mounted) return;

        if (!keepPlaying) {
          up.updateHighScore(gp.score);
          context.go('/result', extra: {
            'question': _question,
            'userAnswer': '__timeout__',
            'isCorrect': false,
            'feedback': result['feedback'],
            'optimalAnswer': result['optimalAnswer'],
            'topic': widget.topic,
            'answerType': widget.answerType,
            'isGameOver': true,
            'questionsAnswered': _questionsAnswered,
            'askedQuestions': List<String>.from(_askedQuestions),
            'levelsGained': levelsGained,
            'xpEarned': _sessionXpEarned,
            'correctAnswersThisSession': _correctAnswersThisSession, // ← ADDED
          });
          return;
        }
      }

      context.go('/result', extra: {
        'question': _question,
        'userAnswer': answer,
        'isCorrect': isCorrect,
        'feedback': result['feedback'],
        'optimalAnswer': result['optimalAnswer'],
        'topic': widget.topic,
        'answerType': widget.answerType,
        'isGameOver': gameOver,
        'questionsAnswered': _questionsAnswered,
        'askedQuestions': List<String>.from(_askedQuestions),
        'levelsGained': levelsGained,
        'xpEarned': _sessionXpEarned,
        'correctAnswersThisSession': _correctAnswersThisSession, // ← ADDED
      });
    } on GroqException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorKind =
            e.isRateLimit ? _ErrorKind.rateLimited : _ErrorKind.serverError;
      });
    } on AllKeysExhaustedException {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorKind = _ErrorKind.allKeysExhausted;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
    }
  }

  Future<bool> _showTimeoutDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius)),
            backgroundColor: Colors.white,
            title: const Text(
              "⏰ Time's Up!",
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: AppTheme.textDark,
              ),
            ),
            content: const Text(
              "You lost a life. Do you want to keep playing or end the session?",
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMid,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'End Session',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: AppTheme.coral,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.purple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Keep Playing',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _endSession() async {
    _timer?.cancel();

    final confirmed = await _showEndSessionDialog();
    if (!confirmed || !mounted) {
      _startTimer();
      return;
    }

    final up = context.read<UserProvider>();
    final gp = context.read<GameProvider>();

    if (_correctAnswersThisSession >= _streakThreshold) {
      up.recordSessionComplete();
    }
    up.updateHighScore(gp.score);

    final levelsGained = up.progress.level - _levelAtSessionStart;

    context.go('/result', extra: {
      'question': _question,
      'userAnswer': '',
      'isCorrect': false,
      'feedback': 'You ended the session.',
      'optimalAnswer': '',
      'topic': widget.topic,
      'answerType': widget.answerType,
      'isGameOver': true,
      'questionsAnswered': _questionsAnswered,
      'askedQuestions': List<String>.from(_askedQuestions),
      'levelsGained': levelsGained,
      'xpEarned': _sessionXpEarned,
      'correctAnswersThisSession': _correctAnswersThisSession, // ← ADDED
    });
  }

  Future<bool> _showEndSessionDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius)),
            backgroundColor: Colors.white,
            title: const Text(
              "End Session?",
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: AppTheme.textDark,
              ),
            ),
            content: const Text(
              "Are you sure you want to end the session? You'll keep your XP and score, but the game will be over.",
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMid,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text(
                  'Keep Playing',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: AppTheme.purple,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'End Session',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    final up = context.watch<UserProvider>();
    final streakEarnedToday = up.progress.streakEarnedToday;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _HUD(
              lives: gp.lives,
              questionsAnswered: _questionsAnswered,
              timeLeft: _timeLeft,
            ),
            Expanded(
              child: _loading
                  ? _buildLoading()
                  : _errorKind != null
                      ? _buildError(_errorKind!)
                      : _buildGame(streakEarnedToday),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.purple),
                strokeWidth: 3),
            SizedBox(height: 16),
            Text(
              'Cooking up a question…',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: AppTheme.textMid,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );

  Widget _buildError(_ErrorKind kind) {
    final config = _errorConfig(kind);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(config.emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text(config.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textDark)),
            const SizedBox(height: 10),
            Text(config.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMid,
                    height: 1.5)),
            const SizedBox(height: 28),
            if (config.showRetry)
              SizedBox(
                width: double.infinity,
                child: _PillButton(
                  label: 'Try Again',
                  color: AppTheme.purple,
                  onTap: _loadQuestion,
                  fullWidth: true,
                ),
              ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => context.go('/'),
              child: Text('Go back home',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textLight,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.textLight)),
            ),
          ],
        ),
      ),
    );
  }

  _ErrorConfig _errorConfig(_ErrorKind kind) {
    switch (kind) {
      case _ErrorKind.rateLimited:
        return const _ErrorConfig(
          emoji: '⏳',
          title: 'Bot needs a breather!',
          message:
              'The AI is taking a short break. We\'re switching to a backup — tap "Try Again" and you\'ll be right back in the game.',
          showRetry: true,
        );
      case _ErrorKind.allKeysExhausted:
        return const _ErrorConfig(
          emoji: '😴',
          title: 'The bot is asleep!',
          message:
              'The AI has answered so many questions today that it needs to rest until midnight. Come back tomorrow — your progress is saved! 💾',
          showRetry: false,
        );
      case _ErrorKind.serverError:
        return const _ErrorConfig(
          emoji: '🔧',
          title: 'Something went wrong',
          message:
              'The AI server is having a moment. Give it a few seconds and try again.',
          showRetry: true,
        );
      case _ErrorKind.unknown:
        return const _ErrorConfig(
          emoji: '📡',
          title: 'Connection issue',
          message: 'Check your internet connection and try again.',
          showRetry: true,
        );
    }
  }

  Widget _buildGame(bool streakEarnedToday) {
    final q = _question!;
    return Column(
      children: [
        _QuestionCard(q: q),
        Expanded(child: _buildInput(q)),
        _SubmitBar(
          submitting: _submitting,
          answerType: q.answerType,
          correctAnswersThisSession: _correctAnswersThisSession,
          streakThreshold: _streakThreshold,
          streakEarnedToday: streakEarnedToday,
          onSubmit: () {
            String ans;
            switch (_resolvedAnswerType) {
              case 'write':
                ans = _textCtrl.text.trim();
              case 'multiple_choice':
                ans = _selectedChoice < 0
                    ? ''
                    : (q.choices?[_selectedChoice] ?? '');
              case 'pick_image':
                ans = _selectedChoice < 0
                    ? ''
                    : (q.imageOptions?[_selectedChoice] ?? '');
              case 'draw':
                ans = _strokes.isEmpty ? '' : _describeStrokes(_strokes);
              default:
                ans = _textCtrl.text.trim();
            }
            _submitAnswer(ans);
          },
          onEndSession: _endSession,
        ),
      ],
    );
  }

  Widget _buildInput(Question q) {
    switch (_resolvedAnswerType) {
      case 'write':
        return _WriteInput(controller: _textCtrl);
      case 'multiple_choice':
        return _MultipleChoice(
            choices: q.choices ?? [],
            selected: _selectedChoice,
            onSelect: (i) => setState(() => _selectedChoice = i));
      case 'pick_image':
        return _PickImage(
            options: q.imageOptions ?? [],
            imageUrls: _imageUrls,
            selected: _selectedChoice,
            onSelect: (i) => setState(() => _selectedChoice = i));
      case 'draw':
        return _DrawCanvas(
          strokes: _strokes,
          onStrokesChanged: (updated) => setState(() => _strokes = updated),
          onClear: () => setState(() => _strokes = []),
        );
      default:
        return _WriteInput(controller: _textCtrl);
    }
  }
}

// ─── Draw stroke geometry → text description ─────────────────────────────────
// Converts raw Offset strokes into a human-readable description that the
// Groq judge can actually reason about. No ML — pure geometric heuristics.
String _describeStrokes(List<List<Offset?>> strokes) {
  // Flatten all valid points
  final points = strokes.expand((s) => s).whereType<Offset>().toList();

  if (points.isEmpty) return '__empty__';

  final strokeCount = strokes.length;
  final totalPoints = points.length;

  // Bounding box
  double minX = points.first.dx, maxX = points.first.dx;
  double minY = points.first.dy, maxY = points.first.dy;
  for (final p in points) {
    if (p.dx < minX) minX = p.dx;
    if (p.dx > maxX) maxX = p.dx;
    if (p.dy < minY) minY = p.dy;
    if (p.dy > maxY) maxY = p.dy;
  }
  final width = maxX - minX;
  final height = maxY - minY;
  final aspectRatio = height == 0 ? 0.0 : width / height;

  // Center of mass
  final cx = points.map((p) => p.dx).reduce((a, b) => a + b) / points.length;
  final cy = points.map((p) => p.dy).reduce((a, b) => a + b) / points.length;

  // Estimate total ink length
  double inkLength = 0;
  for (final stroke in strokes) {
    final valid = stroke.whereType<Offset>().toList();
    for (int i = 1; i < valid.length; i++) {
      inkLength += (valid[i] - valid[i - 1]).distance;
    }
  }

  // Shape descriptors
  final sizeDesc = width < 40 && height < 40
      ? 'very small mark'
      : width < 80 || height < 80
          ? 'small shape'
          : 'full-sized drawing';

  final aspectDesc = aspectRatio > 1.6
      ? 'wider than tall (landscape)'
      : aspectRatio < 0.6
          ? 'taller than wide (portrait)'
          : 'roughly square proportions';

  final strokeDesc = strokeCount == 1
      ? 'drawn in a single continuous stroke'
      : strokeCount <= 3
          ? 'drawn with $strokeCount strokes'
          : 'drawn with $strokeCount strokes (complex)';

  // Circularity approximation: compare ink length to bounding box perimeter
  final bboxPerimeter = 2 * (width + height);
  final circularityHint = bboxPerimeter > 0 && inkLength > 0
      ? (inkLength / bboxPerimeter < 1.4
          ? 'possibly circular or oval'
          : 'non-circular')
      : '';

  // Symmetry hint: is center of mass near the geometric center?
  final geoCx = minX + width / 2;
  final geoCy = minY + height / 2;
  final offsetX = (cx - geoCx).abs() / (width + 1);
  final offsetY = (cy - geoCy).abs() / (height + 1);
  final symmetryHint = offsetX < 0.15 && offsetY < 0.15
      ? 'appears symmetric'
      : 'asymmetric or off-center';

  // Vertical position of mass center (useful for detecting heads/bodies/legs)
  final relCy = height == 0 ? 0.5 : (cy - minY) / height;
  final massHint = relCy < 0.4
      ? 'mass concentrated in upper portion'
      : relCy > 0.6
          ? 'mass concentrated in lower portion'
          : 'mass evenly distributed vertically';

  return 'Drawing analysis: $sizeDesc, $aspectDesc, $strokeDesc. '
      'Bounding box: ${width.toInt()}x${height.toInt()} px. '
      'Ink length: ${inkLength.toInt()} px. '
      '${circularityHint.isNotEmpty ? "$circularityHint, " : ""}'
      '$symmetryHint, $massHint. '
      'Total points: $totalPoints.';
}

// ─── Error types ──────────────────────────────────────────────────────────────

enum _ErrorKind { rateLimited, allKeysExhausted, serverError, unknown }

class _ErrorConfig {
  final String emoji;
  final String title;
  final String message;
  final bool showRetry;
  const _ErrorConfig({
    required this.emoji,
    required this.title,
    required this.message,
    required this.showRetry,
  });
}

// ─── HUD ─────────────────────────────────────────────────────────────────────

class _HUD extends StatelessWidget {
  final int lives;
  final int questionsAnswered;
  final int timeLeft;
  const _HUD({
    required this.lives,
    required this.questionsAnswered,
    required this.timeLeft,
  });

  @override
  Widget build(BuildContext context) {
    final timerColor = timeLeft <= 10
        ? AppTheme.coral
        : timeLeft <= 20
            ? AppTheme.yellow
            : AppTheme.mint;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Row(
              children: List.generate(
                  3,
                  (i) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          i < lives
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: i < lives ? AppTheme.pink : AppTheme.textLight,
                          size: 20,
                        ),
                      ))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Q$questionsAnswered answered',
                style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.purple)),
          ),
          const Spacer(),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: timerColor),
            child: Text(timeLeft.toString().padLeft(2, '0')),
          ),
        ],
      ),
    );
  }
}

// ─── Question card ────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final Question q;
  const _QuestionCard({required this.q});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: AppTheme.cardShadow,
          border:
              Border.all(color: AppTheme.purple.withOpacity(0.15), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text((q.topic ?? 'Question').toUpperCase(),
                    style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.purple,
                        letterSpacing: 1)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(q.prompt, style: AppTheme.body),
          ],
        ),
      );
}

// ─── Write input ──────────────────────────────────────────────────────────────

class _WriteInput extends StatelessWidget {
  final TextEditingController controller;
  const _WriteInput({required this.controller});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            boxShadow: AppTheme.softShadow,
          ),
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            style: const TextStyle(
                fontFamily: 'Nunito', fontSize: 15, color: AppTheme.textDark),
            cursorColor: AppTheme.purple,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.all(18),
              hintText: 'Type your answer here...',
              hintStyle:
                  TextStyle(fontFamily: 'Nunito', color: AppTheme.textLight),
              border: InputBorder.none,
            ),
          ),
        ),
      );
}

// ─── Multiple choice ──────────────────────────────────────────────────────────

class _MultipleChoice extends StatelessWidget {
  final List<String> choices;
  final int selected;
  final ValueChanged<int> onSelect;
  const _MultipleChoice(
      {required this.choices, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        itemCount: choices.length,
        itemBuilder: (_, i) {
          final sel = selected == i;
          return GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sel ? AppTheme.purple.withOpacity(0.08) : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                boxShadow: AppTheme.softShadow,
                border: Border.all(
                  color: sel ? AppTheme.purple : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: sel ? AppTheme.purple : AppTheme.bgSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      String.fromCharCode(65 + i),
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: sel ? Colors.white : AppTheme.textMid),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(choices[i],
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: sel ? AppTheme.textDark : AppTheme.textMid)),
                ),
                if (sel)
                  const Icon(Icons.check_circle_rounded,
                      color: AppTheme.purple, size: 20),
              ]),
            ),
          );
        },
      );
}

// ─── Pick image ───────────────────────────────────────────────────────────────

class _PickImage extends StatelessWidget {
  final List<String> options;
  final List<String?> imageUrls;
  final int selected;
  final ValueChanged<int> onSelect;

  const _PickImage({
    required this.options,
    required this.imageUrls,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    const colors = [
      AppTheme.pink,
      AppTheme.blue,
      AppTheme.yellow,
      AppTheme.mint,
    ];

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 4,
      itemBuilder: (_, i) {
        final sel = selected == i;
        final color = colors[i % colors.length];
        final label = i < options.length ? options[i] : 'Option ${i + 1}';
        final imageUrl = i < imageUrls.length ? imageUrls[i] : null;

        return GestureDetector(
          onTap: () => onSelect(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: sel ? color.withOpacity(0.15) : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              boxShadow: AppTheme.softShadow,
              border: Border.all(
                color: sel ? color : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: color.withOpacity(0.08),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!
                                  : null,
                              color: color,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) =>
                          _LabelFallback(label: label, color: color, sel: sel),
                    )
                  else
                    Container(
                      color: color.withOpacity(0.08),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: color, strokeWidth: 2)),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: Colors.white)),
                    ),
                  ),
                  if (sel)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration:
                            BoxDecoration(color: color, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Label fallback ───────────────────────────────────────────────────────────

class _LabelFallback extends StatelessWidget {
  final String label;
  final Color color;
  final bool sel;
  const _LabelFallback(
      {required this.label, required this.color, required this.sel});

  @override
  Widget build(BuildContext context) => Container(
        color: color.withOpacity(0.08),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: sel ? color : AppTheme.textMid)),
          ),
        ),
      );
}

// ─── Draw canvas ──────────────────────────────────────────────────────────────

class _DrawCanvas extends StatefulWidget {
  final List<List<Offset?>> strokes;
  final ValueChanged<List<List<Offset?>>> onStrokesChanged;
  final VoidCallback onClear;

  const _DrawCanvas({
    required this.strokes,
    required this.onStrokesChanged,
    required this.onClear,
  });

  @override
  State<_DrawCanvas> createState() => _DrawCanvasState();
}

class _DrawCanvasState extends State<_DrawCanvas> {
  late List<List<Offset?>> _strokes;
  List<Offset?> _currentStroke = [];

  @override
  void initState() {
    super.initState();
    _strokes = List.from(widget.strokes);
  }

  void _onPanStart(DragStartDetails d) {
    setState(() {
      _currentStroke = [d.localPosition];
      _strokes = [..._strokes, _currentStroke];
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() => _currentStroke.add(d.localPosition));
  }

  void _onPanEnd(DragEndDetails _) {
    _currentStroke.add(null);
    widget.onStrokesChanged(List.from(_strokes));
  }

  void _clear() {
    setState(() {
      _strokes = [];
      _currentStroke = [];
    });
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: CustomPaint(
                      painter: _DrawPainter(_strokes),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _clear,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.coral.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Clear',
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.coral)),
              ),
            ),
          ],
        ),
      );
}

class _DrawPainter extends CustomPainter {
  final List<List<Offset?>> strokes;
  _DrawPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.purple
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      for (int i = 0; i < stroke.length - 1; i++) {
        if (stroke[i] != null && stroke[i + 1] != null) {
          canvas.drawLine(stroke[i]!, stroke[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DrawPainter old) => old.strokes != strokes;
}

// ─── Submit bar ───────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  final bool submitting;
  final String answerType;
  final int correctAnswersThisSession;
  final int streakThreshold;
  final bool streakEarnedToday;
  final VoidCallback onSubmit;
  final VoidCallback onEndSession;

  const _SubmitBar({
    required this.submitting,
    required this.answerType,
    required this.correctAnswersThisSession,
    required this.streakThreshold,
    required this.streakEarnedToday,
    required this.onSubmit,
    required this.onEndSession,
  });

  @override
  Widget build(BuildContext context) {
    final streakReady = correctAnswersThisSession >= streakThreshold;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          submitting
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(AppTheme.purple),
                            strokeWidth: 2.5)),
                    const SizedBox(width: 12),
                    const Text('Judging your answer...',
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMid)),
                  ],
                )
              : _PillButton(
                  label: 'Submit Answer',
                  color: AppTheme.purple,
                  onTap: onSubmit,
                  fullWidth: true,
                ),
          const SizedBox(height: 10),
          if (!streakEarnedToday) ...[
            _StreakIndicator(
              correctAnswers: correctAnswersThisSession,
              threshold: streakThreshold,
              streakReady: streakReady,
            ),
            const SizedBox(height: 8),
          ],
          GestureDetector(
            onTap: onEndSession,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.textLight.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stop_circle_outlined,
                      size: 16, color: AppTheme.textLight),
                  SizedBox(width: 6),
                  Text('End Session',
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textLight)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Streak indicator ─────────────────────────────────────────────────────────

class _StreakIndicator extends StatelessWidget {
  final int correctAnswers;
  final int threshold;
  final bool streakReady;

  const _StreakIndicator({
    required this.correctAnswers,
    required this.threshold,
    required this.streakReady,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          streakReady
              ? Icons.local_fire_department_rounded
              : Icons.local_fire_department_outlined,
          size: 14,
          color: streakReady ? AppTheme.mint : AppTheme.textLight,
        ),
        const SizedBox(width: 6),
        ...List.generate(threshold, (i) {
          final filled = i < correctAnswers;
          return Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled
                  ? (streakReady ? AppTheme.mint : AppTheme.purple)
                  : AppTheme.textLight.withOpacity(0.25),
            ),
          );
        }),
        const SizedBox(width: 6),
        Text(
          streakReady ? 'Streak earned! 🔥' : '$correctAnswers/$threshold',
          style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: streakReady ? AppTheme.mint : AppTheme.textLight),
        ),
      ],
    );
  }
}

// ─── Pill button ──────────────────────────────────────────────────────────────

class _PillButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;
  const _PillButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: widget.fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: [
              BoxShadow(
                  color: widget.color.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Text(widget.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
      ),
    );
  }
}
