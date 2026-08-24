import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'constants/app_theme.dart';
import 'state/game_provider.dart';
import 'state/telestrator_provider.dart';
import 'state/var_replay_provider.dart';
import 'ui/screens/splash_role_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => VarReplayProvider()),
        ChangeNotifierProvider(create: (_) => TelestratorProvider()),
      ],
      child: const JokarzPlaysApp(),
    ),
  );
}

class JokarzPlaysApp extends StatelessWidget {
  const JokarzPlaysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jokarz Plays',
      debugShowCheckedModeBanner: false,
      theme: JokarzTheme.darkTheme,
      home: const SplashRoleScreen(),
    );
  }
}
