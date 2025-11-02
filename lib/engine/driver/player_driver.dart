import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 玩家驱动器抽象接口
///
/// 每个GamePlayer内部持有的组件，负责为玩家生成决策。
/// 不同类型的玩家使用不同的驱动器实现：
/// - AI玩家使用AIPlayerDriver
/// - 人类玩家使用HumanPlayerDriver
///
/// 设计原则：
/// - 无状态：Driver不持有游戏状态，只通过参数接收
/// - 单向依赖：只依赖GameContext，不依赖Game
/// - 职责单一：只负责生成决策，不负责执行
abstract class PlayerDriver {
  /// 为玩家生成技能响应
  ///
  /// 这是PlayerDriver的核心方法，所有玩家决策都通过此方法生成。
  ///
  /// [player] 执行技能的玩家
  /// [context] 当前游戏上下文（只读快照）
  /// [skill] 要执行的技能
  ///
  /// 返回包含玩家决策的响应对象
  Future<PlayerDriverResponse> request({
    required GamePlayer player,
    required GameContext context,
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
# **你的决策输出**

现在，请根据你的思考，做出最终决策。你的决策必须以一个【纯净的JSON对象】格式提交，绝对不要在JSON前后添加任何注释、解释或Markdown标记（例如 ```json）。

JSON结构如下:
{
  "message": "【我的公开表演】你最终决定在当前环节公开说出的话。这部分内容将向所有人展示，它必须服务于你的最终目标。语言要符合你的角色性格，可以煽动、可以伪装、也可以真诚。如果当前环节不需要发言，则为 null。",
  "reasoning": "【我的内心独白】在这里详细记录你的完整思考过程、逻辑链、对其他玩家身份的猜测、你的策略意图以及你为什么要这么做。这部分只有你自己能看到，是你制定策略的秘密基地。",
  "target": "【我的行动目标】你此次行动/发言/投票所针对的玩家名称，例如 '3号玩家'。如果没有具体目标，则为 null。"
}
''';
}
