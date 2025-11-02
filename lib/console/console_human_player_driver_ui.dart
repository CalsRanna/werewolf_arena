import 'dart:io';
import 'dart:convert';
import 'package:werewolf_arena/engine/driver/human_player_driver_interface.dart';
import 'package:werewolf_arena/engine/event/conspire_event.dart';
import 'package:werewolf_arena/engine/event/discuss_event.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/console/console_game_ui.dart';

/// 控制台人类玩家驱动器UI实现
///
/// 实现了 HumanPlayerDriverInterface 接口，提供完整的控制台UI显示和输入功能
class ConsoleHumanPlayerDriverUI implements HumanPlayerDriverInterface {
  final ConsoleGameUI ui;

  ConsoleHumanPlayerDriverUI(this.ui);

  @override
  void showTurnStart(GamePlayer player, GameContext state, GameSkill skill) {
    ui.printLine();
    ui.printHeader(
      '>>> 轮到你行动了！',
      color: ConsoleColor.bold,
    );
  }

  @override
  void showPlayerInfo(GamePlayer player) {
    ui.printLine('【你的信息】');
    ui.printLine('  玩家编号: ${player.name}');
    ui.printLine('  角色: ${player.role.name}');
    ui.printLine('  状态: ${player.isAlive ? "存活" : "���亡"}');
    ui.printLine();
  }

  @override
  void showGameState(GameContext state) {
    ui.printLine('【游戏状态】');
    ui.printLine('  当前回合: 第 ${state.day} 天');
    ui.printLine('  存活玩家数: ${state.alivePlayers.length}');
    ui.printLine();
  }

  @override
  void showRoundEvents(List<GameEvent> events, GamePlayer player) {
    if (events.isEmpty) return;

    ui.printLine('���本回合发生的事件】');
    for (final event in events) {
      if (event is DiscussEvent) {
        ui.printLine('  第${event.day}天，${event.source.name}发言：...');
      } else if (event is ConspireEvent) {
        ui.printLine('  第${event.day}天，${event.source.name}密谈：...');
      } else {
        ui.printLine('  ${event.toNarrative()}');
      }
    }
    ui.printLine();
    ui.printSeparator('=', 80);
    ui.printLine();
  }

  @override
  Future<String?> requestTargetSelection({
    required List<GamePlayer> alivePlayers,
    required GamePlayer currentPlayer,
    required bool isOptional,
  }) async {
    if (isOptional) {
      ui.printLine('请选择目标玩家（输入玩家编号，或输入"跳过"不使用）:');
    } else {
      ui.printLine('请选择目标玩家（输入玩家编号，如"1号玩家"或直接输入数字"1"）:');
    }

    // 显示可选的目标玩家
    ui.printLine();
    ui.printLine('可选玩家:');
    for (final p in alivePlayers) {
      if (p.id != currentPlayer.id) {
        ui.printLine('  ${p.name}');
      }
    }

    ui.printLine();
    stdout.write('> ');
    stdout.flush();

    final input = readLine();

    // 处理跳过
    if (isOptional &&
        (input == null ||
            input.isEmpty ||
            input == '跳过' ||
            input.toLowerCase() == 'skip')) {
      ui.printLine('已选择不使用该技能');
      return null;
    }

    if (input == null || input.isEmpty) {
      return null;
    }

    // 支持 "1号玩家" 或 "1" 格式
    if (input.contains('号')) {
      return input;
    } else {
      final num = int.tryParse(input);
      if (num != null) {
        return '$num号玩家';
      } else {
        return null; // 无效格式
      }
    }
  }

  @override
  Future<String?> requestMessage() async {
    ui.printLine('请输入你的发言内容（直接输入，回车结束）:');
    stdout.write('> ');
    stdout.flush();

    return readLine();
  }

  @override
  void showDecisionSubmitted() {
    ui.printLine();
    ui.printSeparator('=', 80);
    ui.printLine('>>> 你的决策已提交！');
    ui.printSeparator('=', 80);
    ui.printLine();
  }

  @override
  void showError(String message) {
    ui.printLine();
    ui.printLine('⚠️ $message');
    ui.printLine();
  }

  @override
  void pauseUI() {
    ui.pauseSpinner();
  }

  @override
  void resumeUI() {
    ui.resumeSpinner();
  }

  @override
  String? readLine() {
    // 读取输入（spinner 应该已经在调用前暂停）
    // 显式使用UTF-8编码，确保中文字符正确处理
    final input = stdin.readLineSync(encoding: utf8)?.trim();
    return input;
  }
}
