import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/drivers/player_driver.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

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
