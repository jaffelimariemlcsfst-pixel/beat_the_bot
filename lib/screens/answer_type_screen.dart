import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class _AnswerOption {
  final String emoji;
  final String label;
  final String subtitle;
  final String value;
  final Color color;
  const _AnswerOption(this.emoji, this.label, this.subtitle, this.value, this.color);
}

const _options = [
  _AnswerOption('', 'Write It',        'Type out your answer',      'write',           Color(0xFF9B5DE5)),
  _AnswerOption('', 'Draw It',          'Finger-draw your answer',   'draw',            Color(0xFFFF6B9D)),
  _AnswerOption('', 'Multiple Choice',  'Pick from 4 options',       'multiple_choice', Color(0xFF4ECDC4)),
  _AnswerOption('', 'Pick an Image',    'Choose the right visual',   'pick_image',      Color(0xFFFFD93D)),
];

class AnswerTypeScreen extends StatelessWidget {
  final String? topic;
  const AnswerTypeScreen({super.key, this.topic});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 24, 0),
              child: Row(children: [
                _BackButton(onTap: () => context.go(
                    topic != null ? '/topic-selection' : '/')),
                const SizedBox(width: 12),
                const Text('Answer Style', style: AppTheme.heading),
              ]),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                topic != null
                    ? 'Topic: $topic '
                    : 'Mode: Random Duel ',
                style: AppTheme.label,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ..._options.map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _OptionCard(option: o, topic: topic),
                      )),
                  const SizedBox(height: 4),
                  _RandomCard(topic: topic),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '5 rounds • 3 lives • 60 seconds each',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatefulWidget {
  final _AnswerOption option;
  final String? topic;
  const _OptionCard({required this.option, this.topic});

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard>
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
    final color = widget.option.color;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: () => context.go('/game', extra: {
        'topic': widget.topic,
        'answerType': widget.option.value,
      }),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            boxShadow: AppTheme.cardShadow,
            border: Border.all(color: color.withOpacity(0.25), width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(widget.option.emoji,
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.option.label,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(widget.option.subtitle, style: AppTheme.label),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: color, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _RandomCard extends StatefulWidget {
  final String? topic;
  const _RandomCard({this.topic});

  @override
  State<_RandomCard> createState() => _RandomCardState();
}

class _RandomCardState extends State<_RandomCard>
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
      onTap: () => context.go('/game', extra: {
        'topic': widget.topic,
        'answerType': 'random',
      }),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B9D), Color(0xFF9B5DE5)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            boxShadow: [
              BoxShadow(
                color: AppTheme.pink.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Text(
                'Surprise Me!',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppTheme.softShadow,
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.purple, size: 16),
        ),
      );
}
