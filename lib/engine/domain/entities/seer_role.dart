import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/domain/enums/role_alignment.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/investigate_skill.dart';
import 'package:werewolf_arena/engine/skills/speak_skill.dart';
import 'package:werewolf_arena/engine/skills/vote_skill.dart';

/// 预言家角色
class SeerRole extends GameRole {
  @override
  final Map<String, dynamic> privateData = {};

  @override
  String get roleId => 'seer';

  @override
  String get name => '预言家';

  @override
  String get description => '每晚可以查验一名玩家的身份';

  @override
  RoleAlignment get alignment => RoleAlignment.good;

  @override
  RoleType get type => RoleType.seer;

  @override
  String get rolePrompt => '''
你是预言家，在狼人杀游戏中属于好人阵营。
你拥有查验他人身份的能力，每晚可以查验一名玩家的身份（好人或狼人）。
你的目标是利用查验信息帮助好人阵营找出狼人，但要小心暴露自己的身份。
''';

  @override
  List<GameSkill> get skills => [InvestigateSkill(), SpeakSkill(), VoteSkill()];

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
    if (skill is InvestigateSkill) {
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
    // 预言家死亡时的逻辑
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
