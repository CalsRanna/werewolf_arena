import 'dart:async';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/driver/player_driver.dart';
import 'package:werewolf_arena/engine/driver/human_player_driver_interface.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 人类玩家驱动器
///
/// 用于人类玩家的驱动器实现，通过UI接口等待人类输入决策。
/// 不依赖具体的UI实现，通过 HumanPlayerDriverInterface 与UI层交互。
class HumanPlayerDriver implements PlayerDriver {
  final HumanPlayerDriverInterface _ui;

  HumanPlayerDriver({required HumanPlayerDriverInterface ui}) : _ui = ui;
  @override
  Future<PlayerDriverResponse> request({
    required GamePlayer player,
    required GameState state,
    required GameSkill skill,
  }) async {
    // 暂停 UI 动画，避免与用户输入冲突
    _ui.pauseUI();

    try {
      return await _handleRequest(player: player, state: state, skill: skill);
    } finally {
      // 无论成功或失败，都要恢复 UI 动画
      _ui.resumeUI();
    }
  }

  /// 处理用户输入请求的内部方法
  Future<PlayerDriverResponse> _handleRequest({
    required GamePlayer player,
    required GameState state,
    required GameSkill skill,
  }) async {
    // 显示回合开始提示
    _ui.showTurnStart(player, state, skill);

    // 显示玩家基本信息
    _ui.showPlayerInfo(player);

    // 显示当前游戏状态
    _ui.showGameState(state);

    // 显示本回合发生的事件（对该玩家可见的）
    final visibleEvents = state.events
        .where((event) => event.isVisibleTo(player) && event.day == state.day)
        .toList();
    _ui.showRoundEvents(visibleEvents, player);

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
          target = await _ui.requestTargetSelection(
            alivePlayers: state.alivePlayers,
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
            _ui.showError('该技能必须选择目标，请重新输入');
            continue;
          }

          // 验证目标玩家是否存在
          final targetExists = state.alivePlayers.any((p) => p.name == target);
          if (!targetExists) {
            _ui.showError('目标玩家不存在或已死亡，请重新输入');
            target = null;
            continue;
          }
          validInput = true;
        } catch (e) {
          _ui.showError('输入读取失败: $e');
          continue;
        }
      }
    }

    if (needsMessage) {
      bool validInput = false;
      while (!validInput) {
        try {
          message = await _ui.requestMessage();
          if (message == null || message.isEmpty) {
            _ui.showError('发言不能为空，请重新输入');
            continue;
          }
          validInput = true;
        } catch (e) {
          _ui.showError('输入读取失败: $e');
          continue;
        }
      }
    }

    _ui.showDecisionSubmitted();

    return PlayerDriverResponse(
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
