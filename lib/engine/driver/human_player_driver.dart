import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:werewolf_arena/engine/event/conspire_event.dart';
import 'package:werewolf_arena/engine/event/discuss_event.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/driver/player_driver.dart';
import 'package:werewolf_arena/engine/driver/human_player_driver_input.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

/// 人类玩家驱动器
///
/// 用于人类玩家的驱动器实现，通过输入读取器等待人类输入决策。
/// 不依赖具体的UI实现，只依赖 InputReader 抽象接口。
class HumanPlayerDriver implements PlayerDriver {
  final HumanPlayerDriverInput? _inputReader;

  HumanPlayerDriver({HumanPlayerDriverInput? inputReader})
    : _inputReader = inputReader;
  @override
  Future<PlayerDriverResponse> request({
    required GamePlayer player,
    required GameState state,
    required GameSkill skill,
  }) async {
    // 暂停 UI 动画，避免与用户输入冲突
    _inputReader?.pauseUI();

    try {
      return await _handleRequest(player: player, state: state, skill: skill);
    } finally {
      // 无论成功或失败，都要恢复 UI 动画
      _inputReader?.resumeUI();
    }
  }

  /// 处理用户输入请求的内部方法
  Future<PlayerDriverResponse> _handleRequest({
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
        if (event is DiscussEvent) {
          print('  第${event.day}天，${event.source.name}发言：...');
        } else if (event is ConspireEvent) {
          print('  第${event.day}天，${event.source.name}密谈：...');
        } else {
          print('  ${event.toNarrative()}');
        }
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

      bool validInput = false;
      while (!validInput) {
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
        String? input;
        try {
          input = _readLineSync();
        } catch (e) {
          print('⚠️ 输入读取失败: $e');
          print('请重新输入...');
          continue;
        }

        // 处理跳过
        if (isOptional &&
            (input == null ||
                input.isEmpty ||
                input == '跳过' ||
                input.toLowerCase() == 'skip')) {
          target = null; // 不使用技能
          print('已选择不使用该技能');
          validInput = true;
        } else if (input != null && input.isNotEmpty) {
          // 支持 "1号玩家" 或 "1" 格式
          if (input.contains('号')) {
            target = input;
          } else {
            final num = int.tryParse(input);
            if (num != null) {
              target = '$num号玩家';
            } else {
              print('⚠️ 无效的输入格式，请输入玩家编号（如"1"）');
              continue;
            }
          }

          // 验证目标玩家是否存在
          final targetExists = state.alivePlayers.any((p) => p.name == target);
          if (!targetExists) {
            print('⚠️ 目标玩家不存在或已死亡，请重新输入');
            target = null;
            continue;
          }
          validInput = true;
        } else if (!isOptional) {
          print('⚠️ 该技能必须选择目标，请重新输入');
          continue;
        } else {
          validInput = true;
        }
      }
    }

    if (needsMessage) {
      bool validInput = false;
      while (!validInput) {
        print('\n请输入你的发言内容（直接输入，回车结束）:');
        stdout.write('> ');
        try {
          message = _readLineSync();
          if (message == null || message.isEmpty) {
            print('⚠️ 发言不能为空，请重新输入');
            continue;
          }
          validInput = true;
        } catch (e) {
          print('⚠️ 输入读取失败: $e');
          print('请重新输入...');
          continue;
        }
      }
    }

    // 可选：让玩家输入思考过程
    print('\n[可选] 请简单说明你的思考过程（直接回车跳过）:');
    stdout.write('> ');
    try {
      reasoning = _readLineSync();
    } catch (e) {
      print('⚠️ 输入读取失败，将使用默认值');
      reasoning = '';
    }
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

  /// 读取用户输入
  ///
  /// 如果提供了 InputReader，使用它读取（会自动处理 spinner 等）
  /// 否则直接使用 stdin（用于向后兼容和测试）
  String? _readLineSync() {
    if (_inputReader != null) {
      return _inputReader.readLine();
    }
    // 降级方案：直接使用 stdin，显式使用UTF-8编码
    return stdin.readLineSync(encoding: utf8)?.trim();
  }
}
