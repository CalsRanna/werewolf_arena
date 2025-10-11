/// 事件可见性枚举
enum EventVisibility {
  /// 所有玩家可见
  public,

  /// 仅狼人可见
  allWerewolves,

  /// 仅特定角色可见(例如:预言家的查验结果)
  roleSpecific,

  /// 仅特定玩家可见
  playerSpecific,

  /// 仅死亡玩家可见
  dead,
}
