import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/domain/enums/role_alignment.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/heal_skill.dart';
import 'package:werewolf_arena/engine/skills/poison_skill.dart';
import 'package:werewolf_arena/engine/skills/speak_skill.dart';
import 'package:werewolf_arena/engine/skills/vote_skill.dart';

/// 女巫角色
class WitchRole extends GameRole {
  @override
  final Map<String, dynamic> privateData = {};

  @override
  String get roleId => 'witch';

  @override
  String get name => '女巫';

  @override
  String get description => '拥有一瓶解药和一瓶毒药';

  @override
  RoleAlignment get alignment => RoleAlignment.good;

  @override
  RoleType get type => RoleType.witch;

  @override
  String get rolePrompt => '''
你是女巫，在狼人杀游戏中属于好人阵营。
你拥有一瓶解药和一瓶毒药，各只能使用一次。
解药可以救活当晚被狼人击杀的玩家，毒药可以毒死一名玩家。
请谨慎使用你的药品，它们是扭转局势的关键。
''';

  @override
  List<GameSkill> get skills => [
    HealSkill(),
    PoisonSkill(),
    SpeakSkill(),
    VoteSkill(),
  ];

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
    if (skill is HealSkill || skill is PoisonSkill) {
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
    // 初始化女巫的药品
    setPrivateData('has_antidote', true);
    setPrivateData('has_poison', true);
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
    // 女巫死亡时的逻辑
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
