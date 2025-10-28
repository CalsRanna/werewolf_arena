import 'package:werewolf_arena/engine/role/game_role.dart';
import 'package:werewolf_arena/engine/driver/player_driver.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skill/game_skill.dart';
import 'package:werewolf_arena/engine/skill/skill_result.dart';

/// 游戏玩家抽象基类
///
/// 统一所有玩家的接口，包含基本属性和行为定义
abstract class GamePlayer {
  final PlayerDriver driver;
  final String id;
  final int index;
  final GameRole role;
  final String name;

  int hp = 1;

  /// 玩家记忆：存储高质量的结构化上下文
  /// 在每个回合结束时更新，包含对其他玩家的分析、关键事件摘要等
  String memory = '';

  GamePlayer({
    required this.id,
    required this.index,
    required this.driver,
    required this.role,
    required this.name,
  });

  String get formattedName => "[$name|${role.name}]";

  bool get isAlive => hp > 0;

  Future<SkillResult> cast(GameSkill skill, GameState state);

  void setAlive(bool alive) {
    hp = alive ? 1 : 0;
  }
}
