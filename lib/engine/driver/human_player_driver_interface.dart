import 'package:werewolf_arena/engine/event/game_event.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';

/// 人类玩家驱动器交互接口
///
/// 该接口定义了Engine层与UI层之间的交互协议
/// Engine层通过这个接口请求UI显示和用户输入，但不直接依赖具体的UI实现
abstract class HumanPlayerDriverInterface {
  /// 显示回合开始提示
  ///
  /// [player] 当前玩家
  /// [state] 游戏状态
  /// [skill] 当前技能
  void showTurnStart(GamePlayer player, GameState state, GameSkill skill);

  /// 显示玩家信息
  ///
  /// [player] 当前玩家
  void showPlayerInfo(GamePlayer player);

  /// 显示游戏状态
  ///
  /// [state] 游戏状态
  void showGameState(GameState state);

  /// 显示本回合事件
  ///
  /// [events] 对该玩家可见的事件列表
  /// [player] 当前玩家
  void showRoundEvents(List<GameEvent> events, GamePlayer player);

  /// 请求用户选择目标玩家
  ///
  /// [alivePlayers] 可选的存活玩家列表
  /// [currentPlayer] 当前玩家（会被排除在选项外）
  /// [isOptional] 是否可选（可以跳过）
  ///
  /// 返回选中的玩家名称，如果用户选择跳过则返回null
  Future<String?> requestTargetSelection({
    required List<GamePlayer> alivePlayers,
    required GamePlayer currentPlayer,
    required bool isOptional,
  });

  /// 请求用户输入发言内容
  ///
  /// 返回用户输入的发言内容
  Future<String?> requestMessage();

  /// 显示决策提交成功
  void showDecisionSubmitted();

  /// 显示错误信息
  ///
  /// [message] 错误信息
  void showError(String message);

  /// 暂停 UI 动画（如 spinner）
  ///
  /// 在显示提示信息或输出内容前调用，避免 UI 动画干扰显示
  void pauseUI();

  /// 恢复 UI 动画（如 spinner）
  ///
  /// 在完成所有输出和交互后调用
  void resumeUI();

  /// 读取一行用户输入
  ///
  /// 返回用户输入的字符串，如果读取失败或用户取消返回 null
  /// 这是一个低级接口，通常应该使用更高级的 requestXXX 方法
  String? readLine();
}
