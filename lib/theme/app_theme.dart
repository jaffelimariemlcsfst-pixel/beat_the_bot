import 'package:flutter/material.dart';

class AppTheme {
  static const Color bg        = Color(0xFFFFF0FA);
  static const Color bgCard    = Colors.white;
  static const Color bgSurface = Color(0xFFFAF0FF);

  static const Color pink   = Color(0xFFFF6B9D);
  static const Color purple = Color(0xFF9B5DE5);
  static const Color yellow = Color(0xFFFFD93D);
  static const Color mint   = Color(0xFF00C9A7);
  static const Color coral  = Color(0xFFFF6B6B);
  static const Color blue   = Color(0xFF4ECDC4);

  static const Color textDark  = Color(0xFF2D1B69);
  static const Color textMid   = Color(0xFF8A7AAE);
  static const Color textLight = Color(0xFFBBAADD);

  static const Color correct = Color(0xFF06D6A0);
  static const Color wrong   = Color(0xFFFF6B6B);

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF9B5DE5).withOpacity(0.12),
      blurRadius: 18,
      offset: const Offset(0, 5),
    ),
  ];

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.07),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static const double radius   = 20;
  static const double radiusSm = 12;
  static const double radiusXl = 28;

  static const TextStyle heading = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: textDark,
    letterSpacing: -0.3,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: textMid,
  );

  static const TextStyle body = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: textDark,
    height: 1.5,
  );
}
