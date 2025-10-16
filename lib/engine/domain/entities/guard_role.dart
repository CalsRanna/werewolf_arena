import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/domain/enums/role_alignment.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/protect_skill.dart';
import 'package:werewolf_arena/engine/skills/speak_skill.dart';
import 'package:werewolf_arena/engine/skills/vote_skill.dart';

/// 守卫角色
class GuardRole extends GameRole {
  @override
  final Map<String, dynamic> privateData = {};

  @override
  String get roleId => 'guard';

  @override
  String get name => '守卫';

  @override
  String get description => '每晚可以守护一名玩家，但不能连续两晚守护同一人';

  @override
  RoleAlignment get alignment => RoleAlignment.good;

  @override
  RoleType get type => RoleType.guard;

  @override
  String get prompt => '''
你是守卫，是好人阵营的无声守护者。你的任务是在漫漫长夜中，凭直觉与逻辑找出最值得保护的人，让他们免于狼爪。
你的能力：每晚可以守护一名玩家。
你的限制：【不能连续两晚守护同一个人】。
你的心法：你的挑战在于预判狼人的刀法。预言家是你的首要守护对象，但如果预言家隐藏得很好，一个发言出色的村民或另一个你怀疑是神职的玩家也值得你用生命去守护。保持低调，你的每一次成功守护，都是对狼人计划的致命打击。
''';

  @override
  List<GameSkill> get skills => [ProtectSkill(), SpeakSkill(), VoteSkill()];

  @override
  List<GameSkill> getAvailableSkills(GamePhase phase) {
    return skills.where((skill) => canUseSkillInPhase(skill, phase)).toList();
  }

  @override
  bool get isWerewolf => false;

  @override
  bool get isVillager => false;

  @override
  bool get isGod => true;

  @override
  bool get isGood => true;

  @override
  bool get isEvil => false;

  @override
  bool get isUnique => true;

  @override
  bool canUseSkillInPhase(GameSkill skill, GamePhase phase) {
    if (skill is ProtectSkill) {
      return phase == GamePhase.night;
    } else if (skill is SpeakSkill) {
      return phase == GamePhase.day;
    } else if (skill is VoteSkill) {
      return phase == GamePhase.day;
    }
    return false;
  }

  @override
  void onGameStart(GameState state) {
    // 游戏开始时的初始化逻辑
  }

  @override
  void onNightStart(GameState state) {
    // 夜晚开始时的逻辑
  }

  @override
  void onDayStart(GameState state) {
    // 白天开始时的逻辑
  }

  @override
  void onDeath(dynamic player, DeathCause cause) {
    // 守卫死亡时的逻辑
  }

  @override
  T? getPrivateData<T>(String key) {
    return privateData[key] as T?;
  }

  @override
  void setPrivateData<T>(String key, T value) {
    privateData[key] = value;
  }

  @override
  void removePrivateData(String key) {
    privateData.remove(key);
  }

  @override
  bool hasPrivateData(String key) {
    return privateData.containsKey(key);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'roleId': roleId,
      'name': name,
      'type': type.name,
      'alignment': alignment.name,
      'description': description,
      'isUnique': isUnique,
      'privateData': Map<String, dynamic>.from(privateData),
    };
  }
}
