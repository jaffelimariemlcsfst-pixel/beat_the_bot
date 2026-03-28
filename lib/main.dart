import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/game_provider.dart';
import 'providers/user_provider.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env'); // ← must be first

  final userProvider = UserProvider();
  await userProvider.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>.value(value: userProvider),
        ChangeNotifierProvider(create: (_) => GameProvider()),
      ],
      child: const BeatTheBotApp(),
    ),
  );
}

class BeatTheBotApp extends StatelessWidget {
  const BeatTheBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Beat the Bot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color.fromARGB(255, 245, 245, 245),
      ),
      routerConfig: router,
    );
  }
}