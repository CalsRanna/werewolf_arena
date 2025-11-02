import 'dart:async';

import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/game.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';

/// 人类玩家实现
///
/// 使用HumanPlayerDriver等待人类输入的玩家实现
class HumanPlayer extends GamePlayer {
  // StreamController用于外部UI提交技能结果
  final StreamController<SkillResult> _actionController =
      StreamController<SkillResult>.broadcast();

  HumanPlayer({
    required super.id,
    required super.index,
    required super.driver,
    required super.role,
    required super.name,
  });

  /// 取消当前等待的技能输入
  void cancelSkillInput() {
    if (!_actionController.isClosed) {}
  }

  @override
  Future<SkillResult> cast(GameSkill skill, Game state) async {
    try {
      // 使用Driver处理技能响应（通常是等待人类输入）
      final response = await driver.request(
        player: this,
        state: state,
        skill: skill,
      );
      return SkillResult(
        caster: name,
        target: response.target,
        message: response.message,
        reasoning: response.reasoning,
      );
    } catch (e) {
      return SkillResult(caster: name);
    }
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
