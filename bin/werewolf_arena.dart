import 'dart:io';
import 'package:werewolf_arena/presentation/cli/werewolf_arena.dart';

Future<void> main(List<String> arguments) async {
  final game = WerewolfArenaGame();
  try {
    await game.initialize(arguments);
    await game.run();
  } catch (e) {
    print('Error: $e');
    exit(1);
  } finally {
    exit(0);
  }
}