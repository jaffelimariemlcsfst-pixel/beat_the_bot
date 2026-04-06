import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/user_progress.dart';
import '../providers/user_provider.dart';
import '../providers/game_provider.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().progress;
    final game = context.watch<GameProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 24, 0),
              child: Row(children: [
                _BackButton(onTap: () => context.go('/')),
                const SizedBox(width: 12),
                const UserAvatar(size: 56, showEditButton: true),
                const SizedBox(width: 12),
                const Text('My Profile', style: AppTheme.heading),
                const Spacer(),
                _LogoutButton(),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LevelCard(user: user),
                    const SizedBox(height: 16),
                    _UsernameCard(),
                    const SizedBox(height: 16),
                    _StatsRow(user: user, game: game),
                    const SizedBox(height: 20),
                    const _SectionTitle(title: 'Unlocked Arenas '),
                    const SizedBox(height: 10),
                    _UnlockedArenas(level: user.level),
                    const SizedBox(height: 20),
                    const _SectionTitle(title: 'Badges '),
                    const SizedBox(height: 10),
                    _BadgesSection(user: user),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logout button ─────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Log out?',
                style: TextStyle(
                    fontFamily: 'Nunito', fontWeight: FontWeight.w900)),
            content: const Text('You can log back in anytime.',
                style: TextStyle(fontFamily: 'Nunito')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontFamily: 'Nunito', color: AppTheme.textMid)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Log out',
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        color: AppTheme.coral,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          await context.read<UserProvider>().signOut();
          context.go('/login');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.coral.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.coral.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.logout_rounded, size: 14, color: AppTheme.coral),
            SizedBox(width: 6),
            Text('Logout',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.coral)),
          ],
        ),
      ),
    );
  }
}

// ── Username card ─────────────────────────────────────────────────────────────
class _UsernameCard extends StatefulWidget {
  @override
  State<_UsernameCard> createState() => _UsernameCardState();
}

class _UsernameCardState extends State<_UsernameCard> {
  late TextEditingController _ctrl;
  bool _editing = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final current = provider.username ?? '';

    if (!_initialized && current.isNotEmpty) {
      _ctrl.text = current;
      _initialized = true;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: AppTheme.purple.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_outline_rounded,
                color: AppTheme.purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _editing
                ? TextField(
                    controller: _ctrl,
                    autofocus: true,
                    style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: 'Enter your name',
                      hintStyle: TextStyle(color: AppTheme.textLight),
                    ),
                    onSubmitted: (_) => _save(context, provider),
                  )
                : Text(
                    current.isEmpty ? 'Set your username' : current,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: current.isEmpty
                          ? AppTheme.textLight
                          : AppTheme.textDark,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          if (provider.savingUsername)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.purple))
          else if (_editing)
            Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _editing = false),
                  child: const Icon(Icons.close_rounded,
                      color: AppTheme.textLight, size: 20),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _save(context, provider),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.purple,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Save',
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
              ],
            )
          else
            GestureDetector(
              onTap: () => setState(() => _editing = true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Edit',
                    style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.purple)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, UserProvider provider) async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    try {
      await provider.updateUsername(name);
      if (mounted) setState(() => _editing = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username updated! ✅')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save username.')),
        );
      }
    }
  }
}

// ── Level card ────────────────────────────────────────────────────────────────
class _LevelCard extends StatelessWidget {
  final UserProgress user;
  const _LevelCard({required this.user});

  String _title(int level) {
    if (level >= 20) return 'Void Walker ';
    if (level >= 15) return 'Architect ';
    if (level >= 10) return 'Strategist ';
    if (level >= 5) return 'Thinker ';
    return 'Initiate ';
  }

  @override
  Widget build(BuildContext context) {
    final int level = user.level;

    // ✅ Delegate all XP math to the model — never recompute in the UI
    final int xpEarned = user.xpInCurrentLevel;  // e.g. 160 for user with 360 XP at level 2
    final int xpNeeded = user.xpForNextLevel;     // e.g. 350 (150×2+50)
    final double progress = user.xpProgress;      // e.g. 0.457 (160/350)

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9B5DE5), Color(0xFFFF6B9D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
              color: AppTheme.purple.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const UserAvatar(size: 56, showEditButton: false),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title(level),
                      style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  Text('Level $level',
                      style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.75))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('XP',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.8))),
              // ✅ Shows XP within current level only, e.g. "160 / 350" not "2620 / 600"
              Text('$xpEarned / $xpNeeded',
                  style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.8))),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Container(height: 8, color: Colors.white.withOpacity(0.25)),
                FractionallySizedBox(
                  widthFactor: progress, // ✅ Clamped 0.0–1.0 by the model
                  child: Container(height: 8, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final UserProgress user;
  final GameProvider game;
  const _StatsRow({required this.user, required this.game});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child: _StatTile(
                  label: 'Highest Score',
                  value: '${user.highScore}',
                  emoji: '',
                  color: AppTheme.yellow)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  label: 'Total XP',
                  value: '${user.xp}',
                  emoji: '',
                  color: AppTheme.purple)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatTile(
                  label: 'Best Streak',
                  value: '${user.streak}',
                  emoji: '',
                  color: AppTheme.coral)),
        ],
      );
}

class _StatTile extends StatelessWidget {
  final String label, value, emoji;
  final Color color;
  const _StatTile(
      {required this.label,
      required this.value,
      required this.emoji,
      required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: AppTheme.softShadow,
          border: Border.all(color: color.withOpacity(0.2), width: 2),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color)),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textLight)),
          ],
        ),
      );
}

// ── Unlocked arenas ───────────────────────────────────────────────────────────
class _Arena {
  final String name;
  final int level;
  final Color color;
  const _Arena({required this.name, required this.level, required this.color});
}

class _UnlockedArenas extends StatelessWidget {
  final int level;
  const _UnlockedArenas({required this.level});

  @override
  Widget build(BuildContext context) {
    const topics = <_Arena>[
      _Arena(name: 'Science', level: 0, color: Color(0xFF4ECDC4)),
      _Arena(name: 'History', level: 0, color: Color(0xFFFFD93D)),
      _Arena(name: 'General Knowledge', level: 0, color: Color(0xFF06D6A0)),
      _Arena(name: 'Philosophy', level: 5, color: Color(0xFF9B5DE5)),
      _Arena(name: 'Psychology', level: 5, color: Color(0xFFFF6B9D)),
      _Arena(name: 'Marketing', level: 10, color: Color(0xFFFF9F43)),
      _Arena(name: 'Business', level: 10, color: Color(0xFF54A0FF)),
      _Arena(name: 'Technology', level: 15, color: Color(0xFF5F27CD)),
      _Arena(name: 'Design', level: 15, color: Color(0xFFFF6B6B)),
      _Arena(name: 'The Void', level: 20, color: Color(0xFF2D1B69)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: topics.map((topic) {
        final unlocked = level >= topic.level;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: unlocked
                ? topic.color.withOpacity(0.1)
                : const Color(0xFFF3EFF8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: unlocked
                  ? topic.color.withOpacity(0.4)
                  : AppTheme.textLight.withOpacity(0.3),
            ),
          ),
          child: Text(
            unlocked ? topic.name : 'Lvl ${topic.level}+',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: unlocked ? topic.color : AppTheme.textLight,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Badges ────────────────────────────────────────────────────────────────────
class _Badge {
  final String emoji;
  final String title;
  final Color color;
  const _Badge({required this.emoji, required this.title, required this.color});
}

class _BadgesSection extends StatelessWidget {
  final UserProgress user;
  const _BadgesSection({required this.user});

  List<_Badge> _badges(UserProgress user) {
    final b = <_Badge>[];
    if (user.level >= 1)
      b.add(const _Badge(emoji: '', title: 'First Duel', color: AppTheme.blue));
    if (user.level >= 5)
      b.add(const _Badge(
          emoji: '', title: 'Philosopher', color: AppTheme.purple));
    if (user.level >= 10)
      b.add(const _Badge(emoji: '', title: 'Strategist', color: AppTheme.pink));
    if (user.level >= 20)
      b.add(const _Badge(
          emoji: '', title: 'Void Walker', color: Color(0xFF2D1B69)));
    if (user.xp >= 500)
      b.add(const _Badge(
          emoji: '', title: 'XP Collector', color: AppTheme.yellow));
    return b;
  }

  @override
  Widget build(BuildContext context) {
    final badges = _badges(user);
    if (badges.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          boxShadow: AppTheme.softShadow,
        ),
        child: const Row(
          children: [
            Text('', style: TextStyle(fontSize: 22)),
            SizedBox(width: 12),
            Text('Complete sessions to earn badges!',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMid)),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: badges
          .map((badge) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: badge.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                  border: Border.all(color: badge.color.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(badge.emoji, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Text(badge.title,
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: badge.color)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ── Section title ─────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppTheme.textDark));
}

// ── Back button ───────────────────────────────────────────────────────────────
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

// ── User avatar (reusable) ────────────────────────────────────────────────────
class UserAvatar extends StatelessWidget {
  final double size;
  final bool showEditButton;

  const UserAvatar({
    super.key,
    this.size = 56,
    this.showEditButton = true,
  });

  Future<void> _pickAndUpload(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    final provider = context.read<UserProvider>();
    try {
      await provider.updateAvatar(File(picked.path));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated! 🎉')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upload failed. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final avatarUrl = provider.avatarUrl;
    final isUploading = provider.uploadingAvatar;

    return GestureDetector(
      onTap: showEditButton ? () => _pickAndUpload(context) : null,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.pink, width: 2),
              color: AppTheme.purple.withOpacity(0.3),
            ),
            child: ClipOval(
              child: isUploading
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : avatarUrl != null
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white)),
                          errorBuilder: (_, __, ___) => _defaultIcon(size),
                        )
                      : _defaultIcon(size),
            ),
          ),
          if (showEditButton && !isUploading)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: size * 0.32,
                height: size * 0.32,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: AppTheme.pink),
                child: Icon(Icons.edit, size: size * 0.18, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _defaultIcon(double size) =>
      Icon(Icons.person, size: size * 0.55, color: Colors.white54);
}