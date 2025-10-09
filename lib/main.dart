import 'package:flutter/material.dart';
import 'package:werewolf_arena/di.dart';
import 'package:werewolf_arena/router/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化依赖注入
  DI.ensureInitialized();

  runApp(WerewolfArenaApp());
}

class WerewolfArenaApp extends StatelessWidget {
  const WerewolfArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '狼人杀竞技场',
      routerConfig: router.config(),
      theme: _getTheme(),
    );
  }

  ThemeData _getTheme() {
    var appBarTheme = AppBarTheme(
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 22,
        height: 1.5,
      ),
    );

    var colorScheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: Color(0xFF6366F1), // 紫色主题
    );

    return ThemeData(appBarTheme: appBarTheme, colorScheme: colorScheme);
  }
}
