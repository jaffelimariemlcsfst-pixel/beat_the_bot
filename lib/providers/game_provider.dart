import 'package:flutter/material.dart';

class GameProvider extends ChangeNotifier {
  int _lives = 3;
  int _score = 0;
  int _currentRound = 0;

  int get lives        => _lives;
  int get score        => _score;
  int get currentRound => _currentRound;

  // ── Session lifecycle ──────────────────────────────────────────────────────
  void startSession() {
    _lives        = 5;
    _score        = 0;
    _currentRound = 1;
    notifyListeners();
  }

  // ── Round progression ──────────────────────────────────────────────────────
  void advanceRound() {
    _currentRound++;
    notifyListeners();
  }

  // ── Lives ──────────────────────────────────────────────────────────────────
  void loseLife() {
    if (_lives > 0) _lives--;
    notifyListeners();
  }

  // ── Score ──────────────────────────────────────────────────────────────────
  /// Base points per correct answer is 10.
  /// Bonus: +5 if answered with more than 20 seconds left (fast answer).
  void addScore(int basePoints, {int timeLeft = 0}) {
    final bonus = timeLeft > 20 ? 5 : 0;
    _score += basePoints + bonus;
    notifyListeners();
  }

  // ── Convenience getters ────────────────────────────────────────────────────
  bool get isAlive    => _lives > 0;
  bool get isLastRound => _currentRound >= 5;
  bool get isGameOver  => !isAlive || isLastRound;
}
