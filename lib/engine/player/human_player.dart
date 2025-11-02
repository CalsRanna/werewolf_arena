import 'dart:async';

import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/player/human_player_input.dart';
import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';

/// 人类玩家实现
///
/// 通过HumanPlayerInput接口等待人类输入的玩家实现
class HumanPlayer extends GamePlayer {
  /// 人类输入接口
  final HumanPlayerInput _input;

  // StreamController用于外部UI提交技能结果
  final StreamController<SkillResult> _actionController =
      StreamController<SkillResult>.broadcast();

  HumanPlayer({
    required super.id,
    required super.index,
    required HumanPlayerInput input,
    required super.role,
    required super.name,
  }) : _input = input;

  /// 取消当前等待的技能输入
  void cancelSkillInput() {
    if (!_actionController.isClosed) {}
  }

  @override
  Future<SkillResult> cast(GameSkill skill, GameContext context) async {
    try {
      // 暂停 UI 动画，避免与用户输入冲突
      _input.pauseUI();

      try {
        return await _handleRequest(
          player: this,
          context: context,
          skill: skill,
        );
      } finally {
        // 无论成功或失败，都要恢复 UI 动画
        _input.resumeUI();
      }
    } catch (e) {
      return SkillResult(caster: name);
    }
  }

  /// 处理用户输入请求的内部方法
  Future<SkillResult> _handleRequest({
    required GamePlayer player,
    required GameContext context,
    required GameSkill skill,
  }) async {
    // 显示回合开始提示
    _input.showTurnStart(player, context, skill);

    // 显示玩家基本信息
    _input.showPlayerInfo(player);

    // 显示当前游戏状态
    _input.showGameState(context);

    // 显示本回合发生的事件（对该玩家可见的）
    final visibleEvents = context.events
        .where((event) => event.isVisibleTo(player) && event.day == context.day)
        .toList();
    _input.showRoundEvents(visibleEvents, player);

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
        try {
          target = await _input.requestTargetSelection(
            alivePlayers: context.alivePlayers,
            currentPlayer: player,
            isOptional: isOptional,
          );

          // 如果是可选技能，null表示跳过
          if (target == null && isOptional) {
            validInput = true;
            continue;
          }

          // 如果不是可选技能，null表示输入失败，需要重试
          if (target == null && !isOptional) {
            _input.showError('该技能必须选择目标，请重新输入');
            continue;
          }

          // 验证目标玩家是否存在
          final targetExists = context.alivePlayers.any(
            (p) => p.name == target,
          );
          if (!targetExists) {
            _input.showError('目标玩家不存在或已死亡，请重新输入');
            target = null;
            continue;
          }
          validInput = true;
        } catch (e) {
          _input.showError('输入读取失败: $e');
          continue;
        }
      }
    }

    if (needsMessage) {
      bool validInput = false;
      while (!validInput) {
        try {
          message = await _input.requestMessage();
          if (message == null || message.isEmpty) {
            _input.showError('发言不能为空，请重新输入');
            continue;
          }
          validInput = true;
        } catch (e) {
          _input.showError('输入读取失败: $e');
          continue;
        }
      }
    }

    _input.showDecisionSubmitted();

    return SkillResult(
      caster: name,
      target: target,
      message: message,
      reasoning: reasoning,
    );
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
    return targetSkills.contains(skill.id);
  }

  /// 判断技能是否需要发言
  bool _skillNeedsMessage(GameSkill skill) {
    // 发言、讨论、狼人密谈等需要输入消息
    final messageSkills = [
      'discuss', // 白天发言
      'testament', // 遗言
      'conspire', // 狼人密谈
    ];
    return messageSkills.contains(skill.id);
  }

  /// 判断技能是否可选（可以选择不使用）
  bool _skillIsOptional(GameSkill skill) {
    // 女巫的解药和毒药可以选择不使用
    final optionalSkills = ['witch_heal', 'witch_poison'];
    return optionalSkills.contains(skill.id);
  }

  /// 释放资源
  void dispose() {
    if (!_actionController.isClosed) {
      _actionController.close();
    }
  }

  /// 提供给外部UI调用的方法，用于提交技能执行结果
  void submitSkillResult(SkillResult result) {
    if (!_actionController.isClosed) {
      _actionController.add(result);
    }
  }
}
