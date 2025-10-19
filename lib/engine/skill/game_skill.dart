/// 游戏技能抽象类
///
/// 统一所有游戏行为为技能系统，包括夜晚行动、白天发言、投票等。
/// 每个技能都有自己的提示词、优先级和执行逻辑。
abstract class GameSkill {
  /// 技能唯一标识
  String get skillId;

  /// 技能名称
  String get name;

  /// 技能描述
  String get description;

  /// 技能提示词
  ///
  /// 为AI玩家提供该技能的具体行动指导，包括：
  /// - 技能的使用时机和条件
  /// - 需要考虑的策略因素
  /// - 预期的决策格式
  String get prompt;
}
