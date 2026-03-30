import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/question.dart';
import 'screens/home_screen.dart';
import 'screens/topic_selection_screen.dart';
import 'screens/answer_type_screen.dart';
import 'screens/game_screen.dart';
import 'screens/result_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth_screen.dart';
import 'providers/user_provider.dart';
import 'theme/app_theme.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = context.read<UserProvider>().isLoggedIn;
    final isLoginRoute = state.matchedLocation == '/login';
    if (!isLoggedIn && !isLoginRoute) return '/login';
    if (isLoggedIn && isLoginRoute) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (_, __) => const AuthScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (_, __) => const HomeScreen(),
    ),
    GoRoute(
      path: '/topic-selection',
      builder: (_, __) => const TopicSelectionScreen(),
    ),
    GoRoute(
      path: '/answer-type',
      builder: (_, state) => AnswerTypeScreen(topic: state.extra as String?),
    ),
    GoRoute(
      path: '/game',
      builder: (_, state) {
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        return GameScreen(
          topic: extra['topic'] as String?,
          answerType: extra['answerType'] as String? ?? 'random',
          isNewGame: extra['isNewGame'] as bool? ?? true,
          previousQuestions:
              (extra['previousQuestions'] as List?)?.cast<String>() ?? [],
          questionsAnswered: extra['questionsAnswered'] as int? ?? 0, // ← NEW
        );
      },
    ),
    GoRoute(
      path: '/result',
      builder: (_, state) {
        final e = state.extra as Map<String, dynamic>;
        return ResultScreen(
          question: e['question'] as Question,
          userAnswer: e['userAnswer'] as String,
          isCorrect: e['isCorrect'] as bool,
          feedback: e['feedback'] as String,
          optimalAnswer: e['optimalAnswer'] as String,
          topic: e['topic'] as String?,
          answerType: e['answerType'] as String,
          isGameOver: e['isGameOver'] as bool,
          askedQuestions:
              (e['askedQuestions'] as List?)?.cast<String>() ?? [],
          questionsAnswered: e['questionsAnswered'] as int? ?? 0, // ← NEW
        );
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (_, __) => const ProfileScreen(),
    ),
  ],
  errorBuilder: (_, state) => Scaffold(
    backgroundColor: AppTheme.bg,
    body: Center(
      child: Text(
        'Lost in the void\n${state.uri}',
        style: const TextStyle(
            fontFamily: 'Nunito', color: AppTheme.purple, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    ),
  ),
);