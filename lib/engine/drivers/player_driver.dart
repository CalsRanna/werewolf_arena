import 'package:werewolf_arena/engine/state/game_state.dart';

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
  Future<Map<String, dynamic>> generateSkillResponse({
    required dynamic player, // 使用dynamic避免循环依赖
    required GameState state,
    required String skillPrompt,
    required String expectedFormat,
  });
}
