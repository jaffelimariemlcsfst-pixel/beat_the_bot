import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

class TopicItem {
  final String name;
  final int requiredLevel;
  final List<Color> gradient;
  final IconData icon;

  const TopicItem(this.name, this.requiredLevel, this.gradient, this.icon);
}

const List<TopicItem> kTopics = [
  TopicItem('Science', 0, [Color(0xFF4ECDC4), Color(0xFF44A3AA)],
      Icons.science_rounded),
  TopicItem('History', 0, [Color(0xFFFFD93D), Color(0xFFFF9F43)],
      Icons.auto_stories_rounded),
  TopicItem('General Knowledge', 0, [Color(0xFF06D6A0), Color(0xFF00B4D8)],
      Icons.public_rounded),
  TopicItem('Philosophy', 5, [Color(0xFF9B5DE5), Color(0xFF7B2FBE)],
      Icons.self_improvement_rounded),
  TopicItem('Psychology', 5, [Color(0xFFFF6B9D), Color(0xFFFF4D6D)],
      Icons.psychology_rounded),
  TopicItem('Marketing', 10, [Color(0xFFFF9F43), Color(0xFFFF6B35)],
      Icons.campaign_rounded),
  TopicItem('Business', 10, [Color(0xFF54A0FF), Color(0xFF2E86DE)],
      Icons.business_center_rounded),
  TopicItem('Technology', 15, [Color(0xFF5F27CD), Color(0xFF341F97)],
      Icons.memory_rounded),
  TopicItem('Design', 15, [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
      Icons.palette_rounded),
  TopicItem('The Void', 20, [Color(0xFF2D1B69), Color(0xFF0F0C29)],
      Icons.blur_on_rounded),
];

class TopicSelectionScreen extends StatelessWidget {
  const TopicSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final int userLevel = context.watch<UserProvider>().progress.level;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF0FA), Color(0xFFF0E6FF), Color(0xFFE6F4FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Pick your battle arena',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textMid,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.95,
                    ),
                    itemCount: kTopics.length,
                    itemBuilder: (context, i) {
                      final t = kTopics[i];
                      final unlocked = userLevel >= t.requiredLevel;
                      return _TopicCard(
                        topic: t,
                        unlocked: unlocked,
                        onTap: unlocked
                            ? () => context.go('/answer-type', extra: t.name)
                            : null,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/'),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                boxShadow: AppTheme.softShadow,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.purple, size: 16),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Topic',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                  letterSpacing: -0.3,
                ),
              ),
              Container(
                height: 3,
                width: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.purple, AppTheme.pink],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatefulWidget {
  final TopicItem topic;
  final bool unlocked;
  final VoidCallback? onTap;

  const _TopicCard({required this.topic, required this.unlocked, this.onTap});

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = !widget.unlocked;
    final colors = widget.topic.gradient;

    return GestureDetector(
      onTapDown: locked ? null : (_) => _ctrl.forward(),
      onTapUp: locked ? null : (_) => _ctrl.reverse(),
      onTapCancel: locked ? null : () => _ctrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: locked ? _buildLockedCard() : _buildUnlockedCard(colors),
      ),
    );
  }

  Widget _buildUnlockedCard(List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.45),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          // Shiny overlay
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -10,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        Icon(widget.topic.icon, color: Colors.white, size: 24),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.topic.name,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Play now',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLockedCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border:
            Border.all(color: AppTheme.textLight.withOpacity(0.3), width: 1.5),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.textLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.topic.icon,
                    color: AppTheme.textLight.withOpacity(0.4), size: 24),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.textLight.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded,
                    color: AppTheme.textLight.withOpacity(0.5), size: 14),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.topic.name,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textLight.withOpacity(0.6),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.textLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Level ${widget.topic.requiredLevel}+',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textLight.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
