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
  String get prompt => '''
你是女巫，一位手握生杀大权、亦正亦邪的强大角色。整个游戏的走向，可能就在你的一念之间。
你的能力：你拥有两瓶绝世魔药。
1.  【解药】：在夜晚，当有人被狼人袭击时，你可以选择使用解药救活他。
2.  【毒药】：在夜晚，你可以选择使用毒药杀死任意一名玩家。
你的限制：【两瓶药都只能使用一次】，且在【同一个晚上不能同时使用】。
你的心法：解药无比珍贵，通常应该留给预言家或被狼人错杀的好人。毒药是你的复仇之刃，要用在被你确认的狼人身上。你的信息量很大（知道谁在夜晚死亡），你的决策必须冷静且果断。
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
