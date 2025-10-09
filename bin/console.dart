import 'dart:io';
import 'package:werewolf_arena/widget/console/console_adapter.dart';

Future<void> main(List<String> arguments) async {
  final consoleAdapter = ConsoleAdapter();
  await consoleAdapter.runConsoleMode(arguments);
}