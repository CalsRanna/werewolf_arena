/// 游戏引擎状态枚举
/// 
/// 用于表示游戏引擎的生命周期状态，与GameState的游戏逻辑状态分离
enum GameEngineStatus {
  /// 等待状态 - 引擎已初始化但游戏尚未开始
  waiting('waiting', '等待'),
  
  /// 运行状态 - 游戏正在进行中
  playing('playing', '进行中'),
  
  /// 结束状态 - 游戏已结束
  ended('ended', '已结束');

  const GameEngineStatus(this.value, this.displayName);

  /// 状态值
  final String value;
  
  /// 显示名称
  final String displayName;

  @override
  String toString() => displayName;

  /// 从字符串值获取状态
  static GameEngineStatus? fromValue(String value) {
    for (final status in GameEngineStatus.values) {
      if (status.value == value) {
        return status;
      }
    }
    return null;
  }
}