import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';

class ResultScreen extends StatefulWidget {
  final Question question;
  final String userAnswer;
  final bool isCorrect;
  final String feedback;
  final String optimalAnswer;
  final String? topic;
  final String answerType;
  final bool isGameOver;
  final List<String> askedQuestions;
  final int questionsAnswered;
  final int levelsGained;
  final int xpEarned;
  final int correctAnswersThisSession; // ← ADD

  const ResultScreen({
    super.key,
    required this.question,
    required this.userAnswer,
    required this.isCorrect,
    required this.feedback,
    required this.optimalAnswer,
    this.topic,
    required this.answerType,
    required this.isGameOver,
    this.askedQuestions = const [],
    this.questionsAnswered = 0,
    this.levelsGained = 0,
    this.xpEarned = 0,
    this.correctAnswersThisSession = 0, // ← ADD
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeScale;

  late int _levelsGained;
  late int _xpEarned;

  @override
  void initState() {
    super.initState();
    _levelsGained = widget.levelsGained;
    _xpEarned = widget.xpEarned;

    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeScale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correct = widget.isCorrect;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildBanner(correct),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.userAnswer.isNotEmpty &&
                        widget.userAnswer != '[drawing submitted]') ...[
                      _InfoCard(
                        label: 'Your Answer',
                        content: widget.userAnswer,
                        accent: correct ? AppTheme.correct : AppTheme.wrong,
                        icon: correct ? '✅' : '❌',
                      ),
                      const SizedBox(height: 12),
                    ],
                    _InfoCard(
                      label: 'Best Answer',
                      content: widget.optimalAnswer,
                      accent: AppTheme.mint,
                      icon: '💡',
                    ),
                    const SizedBox(height: 12),
                    _InfoCard(
                      label: 'Explanation',
                      content: widget.feedback,
                      accent: AppTheme.blue,
                      icon: '📖',
                    ),
                    if (correct) ...[
                      const SizedBox(height: 12),
                      _XpBadge(xpEarned: _xpEarned),
                    ],
                    if (widget.isGameOver) ...[
                      const SizedBox(height: 12),
                      const _ScoreSummary(),
                    ],
                    if (widget.isGameOver && _levelsGained > 0) ...[
                      const SizedBox(height: 12),
                      _LevelUpTeaser(levelsGained: _levelsGained),
                    ],
                  ],
                ),
              ),
            ),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(bool correct) {
    final color = correct ? AppTheme.correct : AppTheme.wrong;
    final emoji = correct ? '✅' : '❌';
    final label = correct ? 'Correct!' : 'Not quite…';

    return ScaleTransition(
      scale: _fadeScale,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppTheme.radiusXl)),
          border: Border(
              bottom: BorderSide(color: color.withOpacity(0.2), width: 2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: color)),
            if (widget.isGameOver) ...[
              const SizedBox(height: 4),
              const Text(
                'Session complete! 🎮',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMid),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    // ✅ Only read UserProvider here — GameProvider.score is unreliable after
    //    go_router destroys/recreates the widget tree at session end.
    //    All session state must come from the route extra map (widget params).
    final up = context.read<UserProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: widget.isGameOver
          ? Column(children: [
              _BigButton(
                label: _levelsGained > 0
                    ? 'See Your New Level! 🏆'
                    : 'Play Again 🎮',
                color: _levelsGained > 0 ? AppTheme.pink : AppTheme.purple,
                onTap: () {
                  if (_levelsGained > 0) {
                    context.go('/level-up', extra: {
                      'newLevel': up.progress.level,
                      'xpEarned': _xpEarned,
                      // ✅ Use questionsAnswered from route extra, not gp.score
                      'sessionScore': widget.questionsAnswered,
                    });
                  } else {
                    context.go('/answer-type', extra: widget.topic);
                  }
                },
              ),
              const SizedBox(height: 10),
              _OutlineButton(
                label: _levelsGained > 0 ? 'Maybe later 🏠' : 'Home 🏠',
                onTap: () => context.go('/'),
              ),
            ])
          : Row(children: [
              Expanded(
                child: _OutlineButton(
                  label: 'End 🏁',
                  onTap: () => context.go('/'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigButton(
                  label: 'Next Round',
                  color: AppTheme.purple,
                  onTap: () => context.go('/game', extra: {
                    'topic': widget.topic,
                    'answerType': widget.answerType,
                    'isNewGame': false,
                    'previousQuestions': widget.askedQuestions,
                    'questionsAnswered': widget.questionsAnswered,
                    'correctAnswersThisSession': widget.correctAnswersThisSession, // ← ADD
                  }),
                ),
              ),
            ]),
    );
  }
}

// ─── Level-up teaser card ─────────────────────────────────────────────────────
class _LevelUpTeaser extends StatelessWidget {
  final int levelsGained;
  const _LevelUpTeaser({required this.levelsGained});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.purple.withOpacity(0.12),
              AppTheme.pink.withOpacity(0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.purple.withOpacity(0.3), width: 2),
        ),
        child: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level${levelsGained > 1 ? 's' : ''} Up!',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.purple,
                    ),
                  ),
                  Text(
                    'You gained $levelsGained level${levelsGained > 1 ? 's' : ''}. Tap above to celebrate! 🎉',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: AppTheme.textMid,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ─── Info card ────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String label, content, icon;
  final Color accent;
  const _InfoCard({
    required this.label,
    required this.content,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: AppTheme.softShadow,
          border: Border.all(color: accent.withOpacity(0.25), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: accent,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 8),
            Text(content, style: AppTheme.body),
          ],
        ),
      );
}

// ─── XP badge ─────────────────────────────────────────────────────────────────
class _XpBadge extends StatelessWidget {
  final int xpEarned;
  const _XpBadge({required this.xpEarned});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.yellow.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppTheme.yellow, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⭐', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              xpEarned > 0 ? '+$xpEarned XP this session' : '+20 XP',
              style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Color(0xFFB8860B)),
            ),
          ],
        ),
      );
}

// ─── Score summary ────────────────────────────────────────────────────────────
class _ScoreSummary extends StatelessWidget {
  const _ScoreSummary();

  @override
  Widget build(BuildContext context) {
    final gp = context.watch<GameProvider>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.purple.withOpacity(0.08),
          AppTheme.pink.withOpacity(0.08),
        ]),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.purple.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Text('🎮', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 6),
          Text('Final Score',
              style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMid)),
          Text('${gp.score}',
              style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.purple)),
        ],
      ),
    );
  }
}

// ─── Big button ───────────────────────────────────────────────────────────────
class _BigButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BigButton(
      {required this.label, required this.color, required this.onTap});

  @override
  State<_BigButton> createState() => _BigButtonState();
}

class _BigButtonState extends State<_BigButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _s = Tween(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => _c.forward(),
        onTapUp: (_) => _c.reverse(),
        onTapCancel: () => _c.reverse(),
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _s,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15),
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

// ─── Outline button ───────────────────────────────────────────────────────────
class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: AppTheme.softShadow,
            border: Border.all(color: AppTheme.textLight),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMid)),
        ),
      );
}