class UserProgress {
  final int level;
  final int xp;
  final int highScore;
  final int streak;
  final String? lastPlayedDate; // stored as 'yyyy-MM-dd'
  final List<String> unlockedTopics;

  const UserProgress({
    this.level = 1,
    this.xp = 0,
    this.highScore = 0,
    this.streak = 0,
    this.lastPlayedDate,
    this.unlockedTopics = const ['Science', 'History', 'General Knowledge'],
  });

  // ── XP needed to reach the NEXT level ──────────────────────────────────────
  // Level 1→2: 100xp, 2→3: 200xp, etc.
  int get xpForNextLevel => level * 100;

  // XP accumulated within the current level (for the progress bar)
  int get xpInCurrentLevel => xp - _xpRequiredForLevel(level);

  // Fraction 0.0–1.0 for the XP bar
  double get xpProgress =>
      (xpInCurrentLevel / xpForNextLevel).clamp(0.0, 1.0);

  // Total XP required to reach a given level from scratch
  static int _xpRequiredForLevel(int lvl) {
    // Sum of 100 + 200 + ... + (lvl-1)*100
    if (lvl <= 1) return 0;
    return ((lvl - 1) * lvl ~/ 2) * 100;
  }

  // ── Add XP and auto-level-up ───────────────────────────────────────────────
  UserProgress addXp(int amount) {
    int newXp = xp + amount;
    int newLevel = level;
    List<String> newTopics = List.from(unlockedTopics);

    // Keep levelling up as long as total XP exceeds the threshold
    while (newXp >= _xpRequiredForLevel(newLevel + 1)) {
      newLevel++;
      // Unlock topics at the right thresholds
      newTopics = _unlockTopicsForLevel(newLevel, newTopics);
    }

    return copyWith(xp: newXp, level: newLevel, unlockedTopics: newTopics);
  }

  List<String> _unlockTopicsForLevel(int lvl, List<String> current) {
    final toUnlock = <String>[];
    if (lvl >= 5)  toUnlock.addAll(['Philosophy', 'Psychology']);
    if (lvl >= 10) toUnlock.addAll(['Marketing', 'Business']);
    if (lvl >= 15) toUnlock.addAll(['Technology', 'Design']);
    if (lvl >= 20) toUnlock.add('The Void');

    final updated = List<String>.from(current);
    for (final t in toUnlock) {
      if (!updated.contains(t)) updated.add(t);
    }
    return updated;
  }

  // ── Update high score ──────────────────────────────────────────────────────
  UserProgress updateHighScore(int score) {
    if (score <= highScore) return this;
    return copyWith(highScore: score);
  }

  // ── Update daily streak ────────────────────────────────────────────────────
  UserProgress recordPlayToday() {
    final today = _todayString();
    if (lastPlayedDate == today) {
      // Already played today — no change
      return this;
    }

    final yesterday = _yesterdayString();
    final newStreak = lastPlayedDate == yesterday ? streak + 1 : 1;

    return copyWith(streak: newStreak, lastPlayedDate: today);
  }

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _yesterdayString() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }

  // ── Serialisation ──────────────────────────────────────────────────────────
  UserProgress copyWith({
    int? level,
    int? xp,
    int? highScore,
    int? streak,
    String? lastPlayedDate,
    List<String>? unlockedTopics,
  }) =>
      UserProgress(
        level: level ?? this.level,
        xp: xp ?? this.xp,
        highScore: highScore ?? this.highScore,
        streak: streak ?? this.streak,
        lastPlayedDate: lastPlayedDate ?? this.lastPlayedDate,
        unlockedTopics: unlockedTopics ?? this.unlockedTopics,
      );

  factory UserProgress.fromJson(Map<String, dynamic> json) => UserProgress(
        level: json['level'] as int? ?? 1,
        xp: json['xp'] as int? ?? 0,
        highScore: json['high_score'] as int? ?? 0,
        streak: json['streak'] as int? ?? 0,
        lastPlayedDate: json['last_played_date'] as String?,
        unlockedTopics: json['unlocked_topics'] != null
            ? List<String>.from(json['unlocked_topics'])
            : ['Science', 'History', 'General Knowledge'],
      );

  Map<String, dynamic> toJson() => {
        'level': level,
        'xp': xp,
        'high_score': highScore,
        'streak': streak,
        'last_played_date': lastPlayedDate,
        'unlocked_topics': unlockedTopics,
      };
}
