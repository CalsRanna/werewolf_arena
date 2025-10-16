import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';

/// 玩家驱动器抽象接口
///
/// 每个GamePlayer内部持有的组件，负责为玩家生成决策。
/// 不同类型的玩家使用不同的驱动器实现：
/// - AI玩家使用AIPlayerDriver
/// - 人类玩家使用HumanPlayerDriver
abstract class PlayerDriver {
  /// 为玩家生成技能响应
  ///
  /// 这是PlayerDriver的核心方法，所有玩家决策都通过此方法生成。
  ///
  /// [player] 执行技能的玩家 - 注意：为了避免循环依赖，这里使用dynamic
  /// [state] 当前游戏状态
  /// [skillPrompt] 技能相关的提示词
  /// [expectedFormat] 期望的JSON响应格式
  ///
  /// 返回包含玩家决策的Map，格式由具体技能定义
  Future<PlayerDriverResponse> request({
    required GamePlayer player,
    required GameState state,
    required GameSkill skill,
  });
}

class PlayerDriverResponse {
  final String? target;
  final String? message;
  final String? reasoning;

  const PlayerDriverResponse({this.target, this.message, this.reasoning});

  factory PlayerDriverResponse.fromJson(Map<String, dynamic> json) {
    return PlayerDriverResponse(
      target: json['target'] as String?,
      message: json['message'] as String?,
      reasoning: json['reasoning'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'target': target, 'message': message, 'reasoning': reasoning};
  }

  static String get formatPrompt => '''
请严格按照以下JSON格式返回结果，不得包含其他类似markdown的标记：
{
  "target": "目标玩家名称或者null",
  "message": "发言内容或者null",
  "reasoning": "内心的思考内容"
}
''';
}
