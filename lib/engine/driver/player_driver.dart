import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

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

  /// 更新玩家记忆
  ///
  /// 在阶段结束时调用，将当前阶段的事件提炼成高质量的结构化上下文
  ///
  /// [player] 玩家实例
  /// [currentMemory] 玩家当前的记忆
  /// [currentRoundEvents] 当前阶段发生的对该玩家可见的事件
  /// [state] 当前游戏状态
  ///
  /// 返回更新后的记忆文本
  Future<String> updateMemory({
    required GamePlayer player,
    required String currentMemory,
    required List<GameEvent> currentRoundEvents,
    required GameState state,
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
