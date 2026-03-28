import 'dart:async';
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
  const GameScreen({
    super.key,
    this.topic,
    required this.answerType,
    this.isNewGame = true,
    this.previousQuestions = const [],
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
  String? _error;
  int _timeLeft = 30;
  Timer? _timer;
  int _selectedChoice = -1;
  String _resolvedAnswerType = 'write';
  final List<String> _askedQuestions = [];
  List<List<Offset?>> _strokes = [];
  List<Offset?> _currentStroke = [];
  List<String?> _imageUrls = [];

  @override
  void initState() {
    super.initState();
    _askedQuestions.addAll(widget.previousQuestions);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isNewGame) {
        context.read<GameProvider>().startSession();
        context.read<UserProvider>().recordPlayToday();
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
        _submitAnswer('');
      }
    });
  }

  Future<void> _loadQuestion() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedChoice = -1;
      _textCtrl.clear();
      _strokes = [];
      _currentStroke = [];
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

      // Fetch Unsplash images in parallel AFTER showing the question
      if (type == 'pick_image' &&
          q.imageOptions != null &&
          q.imageOptions!.isNotEmpty) {
        final urls =
            await _unsplashService.fetchImagesForOptions(q.imageOptions!);
        if (mounted) setState(() => _imageUrls = urls);
      }

      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
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
    try {
      final result = await _aiService.judgeAnswer(
          _question!, _question!.correctAnswer, answer);
      if (!mounted) return;
      final gp = context.read<GameProvider>();
      final up = context.read<UserProvider>();
      if (result['isCorrect'] == true) {
        gp.addScore(10, timeLeft: capturedTimeLeft);
        up.addXp(20);
      } else {
        gp.loseLife();
      }
      gp.advanceRound();
      final gameOver = gp.lives <= 0 || gp.currentRound > 5;
      if (gameOver) up.updateHighScore(gp.score);
      context.go('/result', extra: {
        'question': _question,
        'userAnswer': answer,
        'isCorrect': result['isCorrect'],
        'feedback': result['feedback'],
        'optimalAnswer': result['optimalAnswer'],
        'topic': widget.topic,
        'answerType': widget.answerType,
        'isGameOver': gameOver,
        'askedQuestions': List<String>.from(_askedQuestions),
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _HUD(lives: gp.lives, round: gp.currentRound, timeLeft: _timeLeft),
            Expanded(
              child: _loading
                  ? _buildLoading()
                  : _error != null
                      ? _buildError()
                      : _buildGame(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.purple),
                strokeWidth: 3),
            const SizedBox(height: 16),
            Text('Cooking up a question…',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: AppTheme.textMid,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'Nunito',
                      color: AppTheme.textMid,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              _PillButton(
                  label: 'Try Again',
                  color: AppTheme.purple,
                  onTap: _loadQuestion),
            ],
          ),
        ),
      );

  Widget _buildGame() {
    final q = _question!;
    return Column(
      children: [
        _QuestionCard(q: q),
        Expanded(child: _buildInput(q)),
        _SubmitBar(
          submitting: _submitting,
          answerType: q.answerType,
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
                ans = _strokes.isNotEmpty ? '[drawing submitted]' : '';
              default:
                ans = _textCtrl.text.trim();
            }
            _submitAnswer(ans);
          },
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
            currentStroke: _currentStroke,
            onClear: () => setState(() {
                  _strokes = [];
                  _currentStroke = [];
                }),
            onPanStart: (d) => setState(() {
                  _currentStroke = [d.localPosition];
                  _strokes.add(_currentStroke);
                }),
            onPanUpdate: (d) =>
                setState(() => _currentStroke.add(d.localPosition)),
            onPanEnd: (_) => setState(() => _currentStroke.add(null)));
      default:
        return _WriteInput(controller: _textCtrl);
    }
  }
}

// ─── HUD ─────────────────────────────────────────────────────────────────────
class _HUD extends StatelessWidget {
  final int lives, round, timeLeft;
  const _HUD(
      {required this.lives, required this.round, required this.timeLeft});

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
            child: Text('Round $round / 5',
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
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.all(18),
              hintText: 'Type your answer here...',
              hintStyle: const TextStyle(
                  fontFamily: 'Nunito', color: AppTheme.textLight),
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
                  // ── Image or placeholder ──────────────────────────────
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
                      errorBuilder: (_, __, ___) => _LabelFallback(
                        label: label,
                        color: color,
                        sel: sel,
                      ),
                    )
                  else
                    // Still fetching URL — shimmer placeholder
                    Container(
                      color: color.withOpacity(0.08),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: color,
                          strokeWidth: 2,
                        ),
                      ),
                    ),

                  // ── Gradient + label at bottom ────────────────────────
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
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // ── Selected checkmark ────────────────────────────────
                  if (sel)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
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

// ─── Label fallback (when image fails to load) ────────────────────────────────
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
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: sel ? color : AppTheme.textMid,
              ),
            ),
          ),
        ),
      );
}

// ─── Draw canvas ──────────────────────────────────────────────────────────────
class _DrawCanvas extends StatelessWidget {
  final List<List<Offset?>> strokes;
  final List<Offset?> currentStroke;
  final VoidCallback onClear;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  const _DrawCanvas({
    required this.strokes,
    required this.currentStroke,
    required this.onClear,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onPanStart: onPanStart,
                onPanUpdate: onPanUpdate,
                onPanEnd: onPanEnd,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    boxShadow: AppTheme.softShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: CustomPaint(
                        painter: _DrawPainter(strokes), child: Container()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onClear,
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
  bool shouldRepaint(_DrawPainter _) => true;
}

// ─── Submit bar ───────────────────────────────────────────────────────────────
class _SubmitBar extends StatelessWidget {
  final bool submitting;
  final String answerType;
  final VoidCallback onSubmit;
  const _SubmitBar(
      {required this.submitting,
      required this.answerType,
      required this.onSubmit});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: submitting
            ? Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(AppTheme.purple),
                            strokeWidth: 2.5)),
                    const SizedBox(width: 12),
                    Text('Judging your answer...',
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMid)),
                  ],
                ),
              )
            : _PillButton(
                label: 'Submit Answer',
                color: AppTheme.purple,
                onTap: onSubmit,
                fullWidth: true),
      );
}

// ─── Shared button ────────────────────────────────────────────────────────────
class _PillButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool fullWidth;
  const _PillButton(
      {required this.label,
      required this.color,
      required this.onTap,
      this.fullWidth = false});

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