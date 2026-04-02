import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class LevelUpScreen extends StatefulWidget {
  final int newLevel;
  final int xpEarned;
  final int sessionScore;

  const LevelUpScreen({
    super.key,
    required this.newLevel,
    required this.xpEarned,
    required this.sessionScore,
  });

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen>
    with TickerProviderStateMixin {
  // ── Main entrance animation ───────────────────────────────────────────────
  late AnimationController _entranceCtrl;
  late Animation<double> _badgeScale;
  late Animation<double> _badgeFade;
  late Animation<double> _textSlide;

  // ── Continuous pulse on the badge ────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  // ── Confetti particles ────────────────────────────────────────────────────
  late AnimationController _confettiCtrl;
  final List<_Particle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    // Entrance: badge pops in, text slides up
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _badgeScale = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut));
    _badgeFade = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn));
    _textSlide = CurvedAnimation(
        parent: _entranceCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut));

    // Pulse: subtle breathing effect on badge after entrance
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.06)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Confetti: runs for 3 seconds
    _confettiCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..forward();

    // Generate particles
    for (int i = 0; i < 60; i++) {
      _particles.add(_Particle(rng: _rng));
    }

    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _pulseCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  String _titleForLevel(int level) {
    if (level >= 20) return 'Void Walker';
    if (level >= 15) return 'Architect';
    if (level >= 10) return 'Strategist';
    if (level >= 5) return 'Thinker';
    return 'Initiate';
  }

  String _subtitleForLevel(int level) {
    if (level >= 20) return 'You have transcended. The void welcomes you.';
    if (level >= 15) return 'You design the game now. Others just play it.';
    if (level >= 10) return 'Your mind moves three steps ahead.';
    if (level >= 5) return 'Deep questions? You love them.';
    if (level >= 3) return 'You\'re finding your rhythm. Keep going!';
    return 'Every expert was once a beginner. Well done!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0533), // deep purple bg
      body: Stack(
        children: [
          // ── Confetti layer ──────────────────────────────────────────────
          AnimatedBuilder(
            animation: _confettiCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ConfettiPainter(
                  particles: _particles, progress: _confettiCtrl.value),
              size: MediaQuery.of(context).size,
            ),
          ),

          // ── Background glow ─────────────────────────────────────────────
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.purple.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main content ────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                const Spacer(),

                // ── Level badge ───────────────────────────────────────────
                FadeTransition(
                  opacity: _badgeFade,
                  child: ScaleTransition(
                    scale: _badgeScale,
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) => Transform.scale(
                        scale: _pulse.value,
                        child: child,
                      ),
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF9B5DE5), Color(0xFFFF6B9D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.purple.withOpacity(0.6),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: AppTheme.pink.withOpacity(0.4),
                              blurRadius: 60,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🏆',
                                style: TextStyle(fontSize: 42)),
                            Text(
                              '${widget.newLevel}',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Level up label ────────────────────────────────────────
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.5),
                    end: Offset.zero,
                  ).animate(_textSlide),
                  child: FadeTransition(
                    opacity: _textSlide,
                    child: Column(
                      children: [
                        const Text(
                          'LEVEL UP!',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.pink,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _titleForLevel(widget.newLevel),
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            _subtitleForLevel(widget.newLevel),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.7),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // ── Stats row ─────────────────────────────────────────────
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.8),
                    end: Offset.zero,
                  ).animate(_textSlide),
                  child: FadeTransition(
                    opacity: _textSlide,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StatChip(
                              label: 'Session Score',
                              value: '${widget.sessionScore}',
                              color: AppTheme.yellow),
                          const SizedBox(width: 16),
                          _StatChip(
                              label: 'XP Earned',
                              value: '+${widget.xpEarned}',
                              color: AppTheme.mint),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ── CTA buttons ───────────────────────────────────────────
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(_textSlide),
                  child: FadeTransition(
                    opacity: _textSlide,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: Column(
                        children: [
                          _GlowButton(
                            label: 'Keep Playing 🎮',
                            onTap: () => context.go('/'),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => context.go('/profile'),
                            child: Text(
                              'View my profile',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stat chip ────────────────────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
}

// ─── Glow button ──────────────────────────────────────────────────────────────
class _GlowButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GlowButton({required this.label, required this.onTap});

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton>
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
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9B5DE5), Color(0xFFFF6B9D)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.purple.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
}

// ─── Confetti particle model ──────────────────────────────────────────────────
class _Particle {
  final double x;       // 0.0–1.0 starting x position
  final double speed;   // fall speed multiplier
  final double size;
  final Color color;
  final double wobble;  // horizontal sway amount
  final double wobbleSpeed;
  final double rotation;

  _Particle({required Random rng})
      : x = rng.nextDouble(),
        speed = 0.3 + rng.nextDouble() * 0.7,
        size = 6 + rng.nextDouble() * 8,
        color = [
          AppTheme.pink,
          AppTheme.purple,
          AppTheme.yellow,
          AppTheme.mint,
          AppTheme.coral,
          Colors.white,
        ][rng.nextInt(6)],
        wobble = rng.nextDouble() * 30,
        wobbleSpeed = 1 + rng.nextDouble() * 3,
        rotation = rng.nextDouble() * pi * 2;
}

// ─── Confetti painter ─────────────────────────────────────────────────────────
class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0.0 → 1.0 over 3 seconds

  const _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = size.height * progress * p.speed;
      if (y > size.height) continue;

      final x = size.width * p.x +
          sin(progress * pi * 2 * p.wobbleSpeed) * p.wobble;

      final paint = Paint()..color = p.color.withOpacity(1 - progress * 0.5);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + progress * pi * 2);

      // Draw as a small rounded rect (confetti shape)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.5),
          const Radius.circular(2),
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}