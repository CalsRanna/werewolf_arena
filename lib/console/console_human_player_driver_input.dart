import 'dart:io';
import 'dart:convert';
import 'package:werewolf_arena/engine/driver/human_player_driver_input.dart';
import 'package:werewolf_arena/console/console_game_ui.dart';

/// 控制台输入读取器
///
/// 实现了 InputReader 接口，在读取输入时自动管理 spinner 动画。
/// 这样可以避免 spinner 动画与 stdin 阻塞读取并发操作导致 Terminal 崩溃。
class ConsoleHumanPlayerDriverInput implements HumanPlayerDriverInput {
  final ConsoleGameUI ui;

  ConsoleHumanPlayerDriverInput(this.ui);

  @override
  String? readLine() {
    // 读取输入（spinner 应该已经在调用前暂停）
    // 🔑 显式使用UTF-8编码，确保中文字符正确处理
    final input = stdin.readLineSync(encoding: utf8)?.trim();
    return input;
  }

  @override
  void pauseUI() {
    ui.pauseSpinner();
  }

  @override
  void resumeUI() {
    ui.resumeSpinner();
  }
}
