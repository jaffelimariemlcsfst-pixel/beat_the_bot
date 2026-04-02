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

  // ── Gentle curve: XP needed to go from level N to N+1 ────────────────────
  static int _xpNeededForLevel(int lvl) => 150 * lvl + 50;

  // Total cumulative XP required to REACH a given level from scratch
  static int _xpRequiredForLevel(int lvl) {
    if (lvl <= 1) return 0;
    int total = 0;
    for (int i = 1; i < lvl; i++) {
      total += _xpNeededForLevel(i);
    }
    return total;
  }

  // XP needed to complete the current level (denominator on the bar)
  int get xpForNextLevel => _xpNeededForLevel(level);

  // XP earned within the current level (numerator on the bar)
  int get xpInCurrentLevel => xp - _xpRequiredForLevel(level);

  // Fraction 0.0–1.0 for the XP progress bar
  double get xpProgress =>
      (xpInCurrentLevel / xpForNextLevel).clamp(0.0, 1.0);

  // ── Streak earned today ───────────────────────────────────────────────────
  // Returns true if the player already completed a session today.
  // Used by GameScreen to hide the in-game streak indicator once it's locked in.
  bool get streakEarnedToday => lastPlayedDate == _todayString();

  // ── Level names ───────────────────────────────────────────────────────────
  static List<String> levelInfo(int lvl) {
    switch (lvl) {
      case 1:
        return ['Dabba Dabba 🐣', 'Just hatched — barely knows what\'s happening'];
      case 2:
        return ['Jawek Behi 😏', 'Your answer is... fine. We\'ll take it.'];
      case 3:
        return ['El M3allem 🛠️', 'The craftsman has entered the chat'];
      case 4:
        return ['El M3allem Plus ⚡', 'Same M3allem, but faster and more dangerous'];
      case 5:
        return ['El M3allem Pro Max 💪', 'Fully upgraded. Fear him.'];
      case 6:
        return ['El Wa7ch 🐺', 'The beast is loose. Questions tremble.'];
      case 7:
        return ['El Wa7ch Ultra 🔥', 'Ultra mode activated. No question is safe.'];
      case 8:
        return ['El Ostoura 🌟', 'A legend. They tell stories about this one.'];
      case 9:
        return ['El Ostoura Pro 💎', 'Legendarily professional. Even the bot takes notes.'];
      case 10:
        return ['El Ostoura Pro Max 👑', 'The final form. Maximum legend unlocked.'];
      default:
        return ['Makech 3adi 🚀', 'Beyond all levels. Not even human anymore.'];
    }
  }

  String get levelName => levelInfo(level)[0];
  String get levelExplanation => levelInfo(level)[1];

  // ── Add XP and auto-level-up ──────────────────────────────────────────────
  UserProgress addXp(int amount) {
    int newXp = xp + amount;
    int newLevel = level;
    List<String> newTopics = List.from(unlockedTopics);

    while (newXp >= _xpRequiredForLevel(newLevel + 1)) {
      newLevel++;
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

  // ── Update high score ─────────────────────────────────────────────────────
  UserProgress updateHighScore(int score) {
    if (score <= highScore) return this;
    return copyWith(highScore: score);
  }

  // ── Update daily streak ───────────────────────────────────────────────────
  UserProgress recordPlayToday() {
    final today = _todayString();
    if (lastPlayedDate == today) return this;

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

  // ── Serialisation ─────────────────────────────────────────────────────────
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