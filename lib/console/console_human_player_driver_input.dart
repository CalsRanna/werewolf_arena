import 'dart:io';
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
    // 暂停 spinner 避免与 stdin 阻塞冲突
    ui.pauseSpinner();

    try {
      final input = stdin.readLineSync()?.trim();
      return input;
    } finally {
      // 无论成功或失败，都要恢复 spinner
      ui.resumeSpinner();
    }
  }
}
