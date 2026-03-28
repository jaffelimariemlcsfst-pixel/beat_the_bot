import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/user_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glitchController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glitchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final progress = userProvider.progress;

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: Stack(
        children: [
          // Scan line texture
          CustomPaint(
            painter: _ScanLinePainter(),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top accent line
                Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(0, 252, 249, 249),
                        Color(0xFF00FF88),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        // Header row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Level badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF00FF88).withOpacity(0.5),
                                ),
                              ),
                              child: Text(
                                'LVL ${progress.level}',
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  color: Color(0xFF00FF88),
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            // Streak badge with pulse
                            AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (context, _) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF00FF88)
                                          .withOpacity(_pulseAnim.value),
                                    ),
                                    color: const Color(0xFF00FF88)
                                        .withOpacity(0.05 * _pulseAnim.value),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: const Color(0xFF00FF88)
                                              .withOpacity(_pulseAnim.value),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${progress.xp} XP',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                          color: const Color(0xFF00FF88)
                                              .withOpacity(_pulseAnim.value),
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            // Profile button
                            GestureDetector(
                              onTap: () => context.go('/profile'),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.15),
                                  ),
                                ),
                                child: Icon(
                                  Icons.person_outline,
                                  color: Colors.white.withOpacity(0.5),
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        // Title
                        Text(
                          'BEAT',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -2,
                            height: 0.9,
                            shadows: [
                              Shadow(
                                color: const Color(0xFF00FF88).withOpacity(0.3),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'THE',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -2,
                                height: 0.9,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'v2.4',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  color: const Color(0xFF00FF88).withOpacity(0.6),
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'BOT',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00FF88),
                            letterSpacing: -2,
                            height: 0.9,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'PROVE YOU\'RE SMARTER THAN THE MACHINE.',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.35),
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // XP progress bar
                        _buildXpBar(progress),
                        const SizedBox(height: 40),
                        // Mode buttons
                        _ModeButton(
                          icon: '⚡',
                          label: 'RANDOM DUEL',
                          description: 'Any topic. Any format. No prep.',
                          tag: 'QUICK PLAY',
                          onTap: () => context.go('/answer-type',
                              extra: {'mode': 'random'}),
                        ),
                        const SizedBox(height: 12),
                        _ModeButton(
                          icon: '🎯',
                          label: 'FOCUSED DUEL',
                          description: 'Pick your arena. Study smarter.',
                          tag: 'RANKED',
                          onTap: () => context.go('/topic-selection'),
                          accent: false,
                        ),
                        const SizedBox(height: 40),
                        // Stats row
                        _buildStatsRow(progress),
                        const SizedBox(height: 32),
                        // Footer
                        Center(
                          child: Text(
                            '[ ANTHROPIC POWERED — CLAUDE AI ]',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              color: Colors.white.withOpacity(0.15),
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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

  Widget _buildXpBar(dynamic progress) {
    final xpForNext = progress.level * 100;
    final currentXp = progress.xp % (xpForNext == 0 ? 100 : xpForNext);
    final pct = (currentXp / (xpForNext == 0 ? 100 : xpForNext)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'XP TO LEVEL ${progress.level + 1}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: Colors.white.withOpacity(0.3),
                letterSpacing: 2,
              ),
            ),
            Text(
              '$currentXp / $xpForNext',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9,
                color: Colors.white.withOpacity(0.3),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 3,
          width: double.infinity,
          color: Colors.white.withOpacity(0.07),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: pct,
            child: Container(color: const Color(0xFF00FF88)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(dynamic progress) {
    return Row(
      children: [
        _StatBox(label: 'HIGH SCORE', value: '${progress.highScore ?? 0}'),
        const SizedBox(width: 10),
        _StatBox(label: 'LEVEL', value: '${progress.level}'),
        const SizedBox(width: 10),
        _StatBox(
            label: 'ARENAS',
            value: '${progress.unlockedTopics?.length ?? 3}'),
      ],
    );
  }
}

class _ModeButton extends StatefulWidget {
  final String icon;
  final String label;
  final String description;
  final String tag;
  final VoidCallback onTap;
  final bool accent;

  const _ModeButton({
    required this.icon,
    required this.label,
    required this.description,
    required this.tag,
    required this.onTap,
    this.accent = true,
  });

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _hovered
                ? const Color(0xFF00FF88).withOpacity(widget.accent ? 0.1 : 0.05)
                : Colors.white.withOpacity(0.03),
            border: Border(
              left: BorderSide(
                color: widget.accent || _hovered
                    ? const Color(0xFF00FF88)
                    : Colors.white.withOpacity(0.1),
                width: 3,
              ),
              top: BorderSide(
                color: _hovered
                    ? const Color(0xFF00FF88).withOpacity(0.3)
                    : Colors.white.withOpacity(0.07),
              ),
              right: BorderSide(
                color: _hovered
                    ? const Color(0xFF00FF88).withOpacity(0.3)
                    : Colors.white.withOpacity(0.07),
              ),
              bottom: BorderSide(
                color: _hovered
                    ? const Color(0xFF00FF88).withOpacity(0.3)
                    : Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          child: Row(
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF00FF88).withOpacity(0.4),
                      ),
                    ),
                    child: Text(
                      widget.tag,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 8,
                        color: Color(0xFF00FF88),
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.arrow_forward,
                    color: const Color(0xFF00FF88).withOpacity(0.6),
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 8,
                color: Colors.white.withOpacity(0.3),
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.015)
      ..strokeWidth = 1;

    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanLinePainter old) => false;
}
