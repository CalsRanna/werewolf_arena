import 'package:flutter/material.dart';
import 'package:werewolf_arena/database/database.dart';
import 'package:werewolf_arena/di.dart';
import 'package:werewolf_arena/router/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DI.ensureInitialized();
  await Database.instance.ensureInitialized();
  runApp(WerewolfArenaApp());
}

class WerewolfArenaApp extends StatelessWidget {
  const WerewolfArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(routerConfig: router.config());
  }
}
