import 'package:werewolf_arena/core/domain/entities/role.dart';
import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/events/base/game_event.dart';
import 'package:werewolf_arena/core/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/core/drivers/player_driver.dart';
import 'package:werewolf_arena/core/skills/game_skill.dart';
import 'package:werewolf_arena/core/skills/skill_result.dart';

/// 游戏玩家抽象基类
/// 
/// 统一所有玩家的接口，包含基本属性和行为定义
abstract class GamePlayer {
  // 基本属性
  String get id;
  String get name;
  int get index; // 玩家序号（1号玩家、2号玩家等）
  Role get role;
  
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
  
  // Role-based getters
  bool get isWerewolf => role.isWerewolf;
  bool get isVillager => role.isVillager;
  bool get isGod => role.isGod;
  bool get isGood => role.isGood;
  bool get isEvil => role.isEvil;
  bool get isDead => !isAlive;
  
  // 核心方法 - 通过自己的Driver执行技能
  Future<SkillResult> executeSkill(GameSkill skill, GameState state);
  
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
}