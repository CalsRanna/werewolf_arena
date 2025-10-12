import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/domain/enums/role_alignment.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/speak_skill.dart';
import 'package:werewolf_arena/engine/skills/vote_skill.dart';
import 'package:werewolf_arena/engine/skills/shoot_skill.dart';

/// 猎人角色
class HunterRole extends GameRole {
  @override
  final Map<String, dynamic> privateData = {};

  @override
  String get roleId => 'hunter';

  @override
  String get name => '猎人';

  @override
  String get description => '死亡时可以开枪带走一名玩家';

  @override
  RoleAlignment get alignment => RoleAlignment.good;

  @override
  RoleType get type => RoleType.hunter;

  @override
  String get rolePrompt => '''
你是猎人，在狼人杀游戏中属于好人阵营。
你拥有一把猎枪，当你死亡时可以开枪带走一名玩家。
请仔细选择开枪目标，这是你为好人阵营做出的最后贡献。
''';

  @override
  List<GameSkill> get skills => [ShootSkill(), SpeakSkill(), VoteSkill()];

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
    if (skill is ShootSkill) {
      return true; // 猎人可以在死亡时的任何阶段开枪
    } else if (skill is SpeakSkill) {
      return phase == GamePhase.day;
    } else if (skill is VoteSkill) {
      return phase == GamePhase.day;
    }
    return false;
  }

  @override
  void onGameStart(GameState state) {
    // 初始化猎人状态
    setPrivateData('has_shot', false);
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
    // 猎人死亡时激活开枪能力
    if (!hasPrivateData('has_shot') || !getPrivateData<bool>('has_shot')!) {
      setPrivateData('can_shoot', true);
    }
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
