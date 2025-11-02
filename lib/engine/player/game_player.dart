import 'package:werewolf_arena/engine/role/game_role.dart';
import 'package:werewolf_arena/engine/game_context.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';

/// 游戏玩家抽象基类
///
/// 统一所有玩家的接口，包含基本属性和行为定义
///
/// 设计原则：
/// - 无状态：玩家不持有游戏状态，通过GameContext接收
/// - 单向依赖：只依赖Role，不依赖Game
/// - 职责单一：只负责执行技能，不负责游戏流程控制
abstract class GamePlayer {
  final String id;
  final int index;
  final GameRole role;
  final String name;

  int hp = 1;

  /// 是否是警长
  bool isSheriff = false;

  GamePlayer({
    required this.id,
    required this.index,
    required this.role,
    required this.name,
  });

  String get formattedName => "[$name|${role.name}]";

  /// 警徽投票权重(警长为1.5,普通玩家为1.0)
  double get voteWeight => isSheriff ? 1.5 : 1.0;

  bool get isAlive => hp > 0;

  /// 执行技能
  ///
  /// [skill] 要执行的技能
  /// [context] 当前游戏上下文（只读）
  ///
  /// 返回技能执行结果
  Future<SkillResult> cast(GameSkill skill, GameContext context);

  void setAlive(bool alive) {
    hp = alive ? 1 : 0;
  }
}
