// ignore_for_file: avoid_print

import 'dart:io';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';

/// 游戏控制台显示工具类
///
/// 专注于游戏相关的控制台输出和格式化显示
/// 不包含任何日志记录功能,仅负责控制台界面的美化
class ConsoleGameOutput {
  static ConsoleGameOutput? _instance;

  ConsoleGameOutput._internal();

  static ConsoleGameOutput get instance {
    _instance ??= ConsoleGameOutput._internal();
    return _instance!;
  }

  bool _useColors = true;

  /// 初始化控制台设置
  void initialize({bool useColors = true}) {
    _useColors = useColors;
  }

  // === 颜色控制 ===

  String _colorize(String text, ConsoleColor color) {
    if (!_useColors || !stdout.hasTerminal) {
      return text;
    }

    final colorCode = _getColorCode(color);
    return '\x1B[${colorCode}m$text\x1B[0m';
  }

  int _getColorCode(ConsoleColor color) {
    switch (color) {
      case ConsoleColor.red:
        return 31;
      case ConsoleColor.green:
        return 32;
      case ConsoleColor.yellow:
        return 33;
      case ConsoleColor.blue:
        return 34;
      case ConsoleColor.magenta:
        return 35;
      case ConsoleColor.cyan:
        return 36;
      case ConsoleColor.white:
        return 37;
      case ConsoleColor.gray:
        return 90;
      case ConsoleColor.bold:
        return 1;
    }
  }

  String? readLine() {
    stdout.write('请输入回车键继续');
    return stdin.readLineSync();
  }

  // === 基础输出方法 ===

  void printEvent(String text) {
    printLine(_colorize(text, ConsoleColor.green));
  }

  void printLine([String? text]) {
    if (text != null) {
      stdout.writeln('● $text');
    } else {
      stdout.writeln();
    }
  }

  void printLog(String text) {
    stdout.writeln(text);
  }

  void printHeader(String title, {ConsoleColor color = ConsoleColor.cyan}) {
    final border = '=' * 60;
    printLine(_colorize(border, color));
    printLine(_colorize(title, color));
    printLine(_colorize(border, color));
    printLine();
  }

  void printSeparator([String char = '-', int length = 40]) {
    printLine(_colorize(char * length, ConsoleColor.gray));
  }

  // === 游戏相关显示方法 ===

  /// 显示阶段转换信息
  void displayPhaseChange(
    GamePhase oldPhase,
    GamePhase newPhase,
    int dayNumber,
  ) {
    String message;
    ConsoleColor color;

    switch (newPhase) {
      case GamePhase.night:
        message = '🌙 第$dayNumber天夜晚 - 天黑请闭眼';
        color = ConsoleColor.magenta;
        break;
      case GamePhase.day:
        message = '☀️ 第$dayNumber天白天 - 天亮了';
        color = ConsoleColor.yellow;
        break;
      case GamePhase.voting:
        message = '🗳️ 投票阶段开始';
        color = ConsoleColor.blue;
        break;
      case GamePhase.ended:
        message = '🏁 游戏结束';
        color = ConsoleColor.red;
        break;
    }

    printLine();
    printLine(_colorize(message, color));
    printLine();
  }

  /// 显示系统消息(法官公告)
  void displaySystemMessage(String message) {
    var prefix = _colorize('[法官]: ', ConsoleColor.green);
    printLine('$prefix$message');
  }

  /// 显示游戏结束信息
  void displayGameEnd(
    GameState state,
    String winner,
    int totalDays,
    int finalGamePlayerCount,
  ) {
    printLine();
    printHeader('🎊 游戏结束', color: ConsoleColor.green);

    // 胜利阵营
    final winnerText = winner == 'Good' ? '好人阵营' : '狼人阵营';
    printLine(_colorize('🏆 胜利者: ', ConsoleColor.yellow) + winnerText);

    // 游戏统计
    final duration = DateTime.now().difference(state.startTime);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    printLine(
      '${_colorize('⏱️ 游戏时长: ', ConsoleColor.blue)}$minutes分$seconds秒,共$totalDays天',
    );

    printLine();

    // 存活玩家
    printLine(
      '${_colorize('✅ 最终存活: ', ConsoleColor.green)}$finalGamePlayerCount人',
    );
    for (final player in state.alivePlayers) {
      final camp = player.role.id == 'werewolf' ? '狼人' : '好人';
      printLine('  ✓ ${player.name} - ${player.role.name} ($camp)');
    }

    // 死亡玩家
    if (state.deadPlayers.isNotEmpty) {
      printLine();
      printLine(
        '${_colorize('❌ 已出局: ', ConsoleColor.red)}${state.deadPlayers.length}人',
      );
      for (final player in state.deadPlayers) {
        final camp = player.role.id == 'werewolf' ? '狼人' : '好人';
        printLine('  ✗ ${player.name} - ${player.role.name} ($camp)');
      }
    }

    printLine();

    // 身份揭晓
    printLine(_colorize('🔍 身份揭晓:', ConsoleColor.blue));

    // 狼人阵营
    final werewolves = state.players
        .where((p) => p.role.id == 'werewolf')
        .toList();
    printLine(
      _colorize('  🐺 狼人阵营 (${werewolves.length}人):', ConsoleColor.red),
    );
    for (final wolf in werewolves) {
      final status = wolf.isAlive ? '存活' : '出局';
      printLine('     ${wolf.name} - ${wolf.role.name} [$status]');
    }

    // 好人阵营
    final goods = state.players.where((p) => p.role.id != 'werewolf').toList();
    printLine(_colorize('  👼 好人阵营 (${goods.length}人):', ConsoleColor.green));

    final gods = goods.where((p) => p.role.id == 'god').toList();
    if (gods.isNotEmpty) {
      printLine('     神职:');
      for (final god in gods) {
        final status = god.isAlive ? '存活' : '出局';
        printLine('       ${god.name} - ${god.role.name} [$status]');
      }
    }

    final villagers = goods.where((p) => p.role.id == 'villager').toList();
    if (villagers.isNotEmpty) {
      printLine('     平民:');
      for (final villager in villagers) {
        final status = villager.isAlive ? '存活' : '出局';
        printLine('       ${villager.name} - ${villager.role.name} [$status]');
      }
    }

    printLine();
    printHeader('游戏结束', color: ConsoleColor.green);
  }

  /// 显示错误信息
  void displayError(String error, {Object? errorDetails}) {
    printLine();
    printLine(_colorize('❌ 错误: ', ConsoleColor.red) + error);
    if (errorDetails != null) {
      printLine('${_colorize('详情: ', ConsoleColor.gray)}$errorDetails');
    }
    printLine();
  }

  /// 清屏
  void clearScreen() {
    if (stdout.hasTerminal) {
      print('\x1B[2J\x1B[H');
    }
  }
}

/// 控制台颜色枚举
enum ConsoleColor { red, green, yellow, blue, magenta, cyan, white, gray, bold }
