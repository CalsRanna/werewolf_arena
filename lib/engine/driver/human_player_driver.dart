import 'dart:async';
import 'dart:io';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/driver/player_driver.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 人类玩家驱动器
///
/// 用于人类玩家的驱动器实现，通过控制台等待人类输入决策
class HumanPlayerDriver implements PlayerDriver {
  @override
  Future<PlayerDriverResponse> request({
    required GamePlayer player,
    required GameState state,
    required GameSkill skill,
  }) async {
    // 显示分隔线
    print('\n${'=' * 80}');
    print('>>> 轮到你行动了！');
    print('=' * 80);

    // 显示玩家基本信息
    print('\n【你的信息】');
    print('  玩家编号: ${player.name}');
    print('  角色: ${player.role.name}');
    print('  状态: ${player.isAlive ? "存活" : "死亡"}');

    // 显示当前游戏状态
    print('\n【游戏状态】');
    print('  当前回合: 第 ${state.day} 天');
    print('  存活玩家数: ${state.alivePlayers.length}');

    // 本回合发生的事件（对该玩家可见的）
    final visibleEvents = state.events
        .where((event) => event.isVisibleTo(player) && event.day == state.day)
        .toList();
    if (visibleEvents.isNotEmpty) {
      print('\n【本回合发生的事件】');
      for (final event in visibleEvents) {
        print('  ${event.toNarrative()}');
      }
    }

    print('\n${'=' * 80}');

    // 根据技能类型决定需要什么样的输入
    String? target;
    String? message;
    String? reasoning;

    // 判断是否需要选择目标
    final needsTarget = _skillNeedsTarget(skill);
    final needsMessage = _skillNeedsMessage(skill);

    if (needsTarget) {
      // 判断是否是可选技能（女巫的药可以选择不使用）
      final isOptional = _skillIsOptional(skill);

      if (isOptional) {
        print('\n请选择目标玩家（输入玩家编号，或输入"跳过"不使用）:');
      } else {
        print('\n请选择目标玩家（输入玩家编号，如"1号玩家"或直接输入数字"1"）:');
      }

      // 显示可选的目标玩家
      print('\n可选玩家:');
      for (final p in state.alivePlayers) {
        if (p.id != player.id) {
          // 不显示自己
          print('  ${p.name}');
        }
      }

      stdout.write('\n> ');
      final input = stdin.readLineSync()?.trim();

      // 处理跳过
      if (isOptional &&
          (input == null ||
              input.isEmpty ||
              input == '跳过' ||
              input.toLowerCase() == 'skip')) {
        target = null; // 不使用技能
        print('已选择不使用该技能');
      } else if (input != null && input.isNotEmpty) {
        // 支持 "1号玩家" 或 "1" 格式
        if (input.contains('号')) {
          target = input;
        } else {
          final num = int.tryParse(input);
          if (num != null) {
            target = '$num号玩家';
          } else {
            print('⚠️ 无效的输入，将跳过此操作');
          }
        }

        // 验证目标玩家是否存在
        if (target != null) {
          final targetExists = state.alivePlayers.any((p) => p.name == target);
          if (!targetExists) {
            print('⚠️ 警告: 目标玩家不存在或已死亡，请确认输入');
          }
        }
      }
    }

    if (needsMessage) {
      print('\n请输入你的发言内容（直接输入，回车结束）:');
      stdout.write('> ');
      message = stdin.readLineSync()?.trim();
    }

    // 可选：让玩家输入思考过程
    print('\n[可选] 请简单说明你的思考过程（直接回车跳过）:');
    stdout.write('> ');
    reasoning = stdin.readLineSync()?.trim();
    if (reasoning?.isEmpty ?? true) {
      reasoning = '人类玩家的决策';
    }

    print('\n${'=' * 80}');
    print('>>> 你的决策已提交！');
    print('=' * 80 + '\n');

    return PlayerDriverResponse(
      target: target,
      message: message,
      reasoning: reasoning,
    );
  }

  @override
  Future<String> updateMemory({
    required GamePlayer player,
    required String currentMemory,
    required List<GameEvent> currentRoundEvents,
    required GameState state,
  }) async {
    // 人类玩家不需要自动更新记忆，直接返回当前记忆
    return currentMemory;
  }

  /// 判断技能是否需要选择目标
  bool _skillNeedsTarget(GameSkill skill) {
    // 根据技能ID判断是否需要目标
    // 投票、击杀、治疗、保护等技能需要目标
    final targetSkills = [
      'vote',
      'werewolf_kill',
      'witch_heal',
      'witch_poison',
      'guard_protect',
      'seer_check',
      'hunter_shoot',
      'conspire', // 狼人讨论时选择击杀目标
    ];
    return targetSkills.contains(skill.skillId);
  }

  /// 判断技能是否需要发言
  bool _skillNeedsMessage(GameSkill skill) {
    // 发言、讨论、狼人密谈等需要输入消息
    final messageSkills = [
      'discuss', // 白天发言
      'testament', // 遗言
      'conspire', // 狼人密谈
    ];
    return messageSkills.contains(skill.skillId);
  }

  /// 判断技能是否可选（可以选择不使用）
  bool _skillIsOptional(GameSkill skill) {
    // 女巫的解药和毒药可以选择不使用
    final optionalSkills = ['witch_heal', 'witch_poison'];
    return optionalSkills.contains(skill.skillId);
  }
}
