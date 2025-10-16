import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/drivers/player_driver.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';
import 'package:werewolf_arena/engine/domain/entities/ai_player.dart';
import 'package:werewolf_arena/engine/domain/entities/human_player.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';

/// 游戏玩家抽象基类
///
/// 统一所有玩家的接口，包含基本属性和行为定义
abstract class GamePlayer {
  // 基本属性
  String get id;
  String get name;
  int get index; // 玩家序号（1号玩家、2号玩家等）
  GameRole get role;

  // 每个玩家有自己的Driver
  PlayerDriver get driver;

  // 状态
  bool get isAlive;
  bool get isProtected;
  bool get isSilenced;

  // 私有数据管理
  Map<String, dynamic> get privateData;

  // 历史行动
  List<GameEvent> get actionHistory;

  // GameRole-based getters
  bool get isWerewolf => role.isWerewolf;
  bool get isVillager => role.isVillager;
  bool get isGod => role.isGod;
  bool get isGood => role.isGood;
  bool get isEvil => role.isEvil;
  bool get isDead => !isAlive;
  set isDead(bool dead) => setAlive(!dead);

  // 核心方法 - 通过自己的Driver执行技能
  Future<SkillResult> cast(GameSkill skill, GameState state);

  // 事件处理
  void onGameEvent(GameEvent event);
  void onDeath(DeathCause cause);
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase);

  // 状态检查
  bool canAct(GamePhase phase);
  bool canVote();
  bool canSpeak();

  // 状态修改方法
  void setAlive(bool alive);
  void setProtected(bool protected);
  void setSilenced(bool silenced);

  // Skill management
  int getSkillUses(String skillId);
  void useSkill(String skillId);

  // Private data management
  T? getPrivateData<T>(String key);
  void setPrivateData<T>(String key, T value);
  void removePrivateData(String key);
  bool hasPrivateData(String key);

  // Action management
  void addAction(GameEvent action);

  // Knowledge and memory
  void addKnowledge(String key, dynamic value);
  T? getKnowledge<T>(String key);
  bool hasKnowledge(String key);

  // Status and info
  String getStatus();
  String get formattedName;

  // Death handling
  void die(DeathCause cause, GameState state);

  // Serialization
  Map<String, dynamic> toJson();

  @override
  String toString() {
    return '$name (${role.name})';
  }

  // 静态工厂方法，用于测试和外部创建
  /// 创建AI玩家
  static AIPlayer ai({
    required String id,
    required String name,
    required GameRole role,
    PlayerDriver? driver,
  }) {
    // 创建默认的PlayerIntelligence用于测试
    final intelligence = PlayerIntelligence(
      baseUrl: 'https://api.openai.com/v1',
      apiKey: 'test-key',
      modelId: 'gpt-3.5-turbo',
    );

    return AIPlayer(
      id: id,
      name: name,
      index: 1, // 默认索引，实际使用时会被正确设置
      role: role,
      intelligence: intelligence,
    );
  }

  /// 创建人类玩家
  static HumanPlayer human({
    required String id,
    required String name,
    required GameRole role,
  }) {
    return HumanPlayer(
      id: id,
      name: name,
      index: 1, // 默认索引，实际使用时会被正确设置
      role: role,
    );
  }
}
