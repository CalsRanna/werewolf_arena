/// 游戏阶段枚举
enum GamePhase {
  /// 夜晚阶段
  night,

  /// 白天阶段
  day,

  /// 投票阶段
  voting,

  /// 游戏结束
  ended;

  /// 获取显示名称
  String get displayName {
    switch (this) {
      case GamePhase.night:
        return 'Night';
      case GamePhase.day:
        return 'Day';
      case GamePhase.voting:
        return 'Voting';
      case GamePhase.ended:
        return 'Ended';
    }
  }
}
