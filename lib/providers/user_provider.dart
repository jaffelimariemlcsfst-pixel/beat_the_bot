import 'dart:io';
import 'package:flutter/material.dart';
import '../models/user_progress.dart';
import '../services/supabase_service.dart';

class UserProvider extends ChangeNotifier {
  UserProgress _progress = const UserProgress();
  final SupabaseService _supabase = SupabaseService();

  UserProgress get progress => _progress;
  bool get isLoggedIn => _supabase.isLoggedIn;
  String? get userId => _supabase.userId;

  // ─── AVATAR ───────────────────────────────────────────────────────────────
  String? _avatarUrl;
  String? get avatarUrl => _avatarUrl;

  bool _uploadingAvatar = false;
  bool get uploadingAvatar => _uploadingAvatar;

  // ─── USERNAME ─────────────────────────────────────────────────────────────
  String? _username;
  String? get username => _username;

  bool _savingUsername = false;
  bool get savingUsername => _savingUsername;

  // ─── SESSION RESTORE ──────────────────────────────────────────────────────

  /// Call once at app startup. Restores token and proactively refreshes it.
  Future<void> restoreSession() async {
    final restored = await _supabase.restoreSession();
    if (restored) {
      await _supabase.refreshSession();
      await _loadAllUserData();
      notifyListeners();
    }
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────

  Future<void> signIn(String email, String password) async {
    await _supabase.signIn(email, password);
    await _loadAllUserData();
    notifyListeners();
  }

  Future<void> signUp(String email, String password) async {
    await _supabase.signUp(email, password);
    if (_supabase.userId != null) {
      await _supabase.saveProgress(_supabase.userId!, _progress);
    }
    await _loadAllUserData();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _supabase.signOut();
    _progress = const UserProgress();
    _avatarUrl = null;
    _username = null;
    notifyListeners();
  }

  // ─── INTERNAL LOADER ──────────────────────────────────────────────────────

  Future<void> _loadAllUserData() async {
    if (_supabase.userId == null) return;
    final saved = await _supabase.loadProgress(_supabase.userId!);
    if (saved != null) _progress = saved;
    _username = await _supabase.getUsername();
    _loadAvatarUrl();
  }

  void _loadAvatarUrl() {
    try {
      _avatarUrl = _supabase.getAvatarUrl();
    } catch (_) {
      _avatarUrl = null;
    }
  }

  // ─── TOKEN REFRESH HELPER ─────────────────────────────────────────────────

  Future<T> _withTokenRefresh<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (e) {
      if (e.toString().contains('JWT expired') ||
          e.toString().contains('PGRST303')) {
        final refreshed = await _supabase.refreshSession();
        if (!refreshed) {
          await signOut();
          throw Exception('Session expired. Please log in again.');
        }
        return await call();
      }
      rethrow;
    }
  }

  // ─── USERNAME ─────────────────────────────────────────────────────────────

  Future<void> updateUsername(String newName) async {
    _savingUsername = true;
    notifyListeners();
    try {
      await _withTokenRefresh(() => _supabase.updateUsername(newName));
      _username = newName;
    } catch (e) {
      debugPrint('Username update error: $e');
      rethrow;
    } finally {
      _savingUsername = false;
      notifyListeners();
    }
  }

  // ─── AVATAR ───────────────────────────────────────────────────────────────

  Future<void> updateAvatar(File imageFile) async {
    _uploadingAvatar = true;
    notifyListeners();
    try {
      final url =
          await _withTokenRefresh(() => _supabase.uploadAvatar(imageFile));
      _avatarUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('Avatar upload error: $e');
      rethrow;
    } finally {
      _uploadingAvatar = false;
      notifyListeners();
    }
  }

  // ─── PROGRESS ─────────────────────────────────────────────────────────────

  void loadProgress(UserProgress loaded) {
    _progress = loaded;
    notifyListeners();
  }

  /// Adds XP and returns the number of levels gained (0 if no level-up).
  /// Callers use the return value to decide whether to show the level-up screen.
  ///
  /// Example:
  ///   final levelsGained = up.addXp(20);
  ///   if (levelsGained > 0 && widget.isGameOver) {
  ///     context.go('/level-up', extra: { ... });
  ///   }
  int addXp(int amount) {
    final levelBefore = _progress.level;
    _progress = _progress.addXp(amount);
    notifyListeners();
    _syncProgress();
    // Returns how many levels were gained — 0 means no celebration needed
    return _progress.level - levelBefore;
  }

  void updateHighScore(int score) {
    _progress = _progress.updateHighScore(score);
    notifyListeners();
    _syncProgress();
  }

  // ─── STREAK ───────────────────────────────────────────────────────────────

  /// Called when a session ends with ≥5 questions answered.
  /// Streak logic lives in UserProgress.recordPlayToday():
  ///   - played today already  → no change (idempotent)
  ///   - played yesterday      → streak + 1
  ///   - not played in 2+ days → streak resets to 1
  void recordSessionComplete() {
    _progress = _progress.recordPlayToday();
    notifyListeners();
    _syncProgress();
  }

  // ─── SYNC ─────────────────────────────────────────────────────────────────

  Future<void> _syncProgress() async {
    if (!isLoggedIn || userId == null) return;
    try {
      await _withTokenRefresh(
          () => _supabase.saveProgress(userId!, _progress));
    } catch (_) {}
  }
}