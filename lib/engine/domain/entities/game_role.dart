import 'package:werewolf_arena/engine/state/game_state.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';
import 'package:werewolf_arena/engine/domain/enums/role_alignment.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';

/// 游戏角色抽象基类
///
/// 定义角色能力、技能和行为，成为完整的角色实体
abstract class GameRole {
  // 基础信息
  String get roleId;
  String get name;
  String get description;
  RoleAlignment get alignment;
  RoleType get type;

  // 角色身份提示词
  String get rolePrompt; // 定义角色身份和阵营目标

  // 技能系统
  List<GameSkill> get skills; // 角色拥有的技能列表
  List<GameSkill> getAvailableSkills(GamePhase phase); // 获取指定阶段可用技能

  // 角色属性
  bool get isWerewolf;
  bool get isVillager;
  bool get isGod;
  bool get isGood;
  bool get isEvil;
  bool get isUnique;

  // 事件响应
  void onGameStart(GameState state);
  void onNightStart(GameState state);
  void onDayStart(GameState state);
  void onDeath(dynamic player, DeathCause cause);

  // 私有数据管理（用于角色特定状态）
  Map<String, dynamic> get privateData;
  T? getPrivateData<T>(String key);
  void setPrivateData<T>(String key, T value);
  void removePrivateData(String key);
  bool hasPrivateData(String key);

  // 工具方法
  bool canUseSkillInPhase(GameSkill skill, GamePhase phase);

  // 序列化
  Map<String, dynamic> toJson();

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GameRole && other.roleId == roleId;
  }

  @override
  int get hashCode => roleId.hashCode;
}
