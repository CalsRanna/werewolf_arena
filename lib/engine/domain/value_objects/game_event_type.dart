/// 游戏事件类型枚举
enum GameEventType {
  /// 游戏开始
  gameStart,

  /// 游戏结束
  gameEnd,

  /// 阶段转换
  phaseChange,

  /// 玩家死亡
  playerDeath,

  /// 玩家行动
  playerAction,

  /// 技能使用
  skillUsed,

  /// 技能结果
  skillResult,

  /// 投票
  voteCast,

  /// 天亮
  dayBreak,

  /// 夜晚降临
  nightFall,
}
