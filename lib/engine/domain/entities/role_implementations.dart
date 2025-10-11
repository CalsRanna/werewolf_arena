import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/state/game_state.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';
import 'package:werewolf_arena/engine/domain/enums/role_alignment.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/base_skills.dart';

/// 村民角色
class VillagerRole extends GameRole {
  @override
  final Map<String, dynamic> privateData = {};

  @override
  String get roleId => 'villager';

  @override
  String get name => '村民';

  @override
  String get description => '普通村民，没有特殊技能，通过推理和投票找出狼人';

  @override
  RoleAlignment get alignment => RoleAlignment.good;

  @override
  RoleType get type => RoleType.villager;

  @override
  String get rolePrompt => '''
你是一个村民，在狼人杀游戏中属于好人阵营。
你的目标是通过推理和投票找出所有狼人。
虽然你没有特殊技能，但你可以通过观察、分析和投票来帮助好人阵营获胜。
''';

  @override
  List<GameSkill> get skills => [SpeakSkill(), VoteSkill()];

  @override
  List<GameSkill> getAvailableSkills(GamePhase phase) {
    return skills.where((skill) => canUseSkillInPhase(skill, phase)).toList();
  }

  @override
  bool get isWerewolf => false;

  @override
  bool get isVillager => true;

  @override
  bool get isGod => false;

  @override
  bool get isGood => true;

  @override
  bool get isEvil => false;

  @override
  bool get isUnique => false;

  @override
  bool canUseSkillInPhase(GameSkill skill, GamePhase phase) {
    if (skill is SpeakSkill) {
      return phase == GamePhase.day;
    } else if (skill is VoteSkill) {
      return phase == GamePhase.day; // 投票是白天的一部分
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
    // 村民死亡时的逻辑
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

/// 狼人角色
class WerewolfRole extends GameRole {
  @override
  final Map<String, dynamic> privateData = {};

  @override
  String get roleId => 'werewolf';

  @override
  String get name => '狼人';

  @override
  String get description => '每晚可以击杀一名玩家，狼人之间相互认识';

  @override
  RoleAlignment get alignment => RoleAlignment.evil;

  @override
  RoleType get type => RoleType.werewolf;

  @override
  String get rolePrompt => '''
你是一个狼人，在狼人杀游戏中属于狼人阵营。
你的目标是与队友合作，消灭所有好人。
你们可以在夜晚讨论并选择击杀目标，白天需要隐藏身份并误导好人。
''';

  @override
  List<GameSkill> get skills => [
    WerewolfKillSkill(),
    SpeakSkill(),
    VoteSkill(),
  ];

  @override
  List<GameSkill> getAvailableSkills(GamePhase phase) {
    return skills.where((skill) => canUseSkillInPhase(skill, phase)).toList();
  }

  @override
  bool get isWerewolf => true;

  @override
  bool get isVillager => false;

  @override
  bool get isGod => false;

  @override
  bool get isGood => false;

  @override
  bool get isEvil => true;

  @override
  bool get isUnique => false;

  @override
  bool canUseSkillInPhase(GameSkill skill, GamePhase phase) {
    if (skill is WerewolfKillSkill) {
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
    // 狼人死亡时的逻辑
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
  List<GameSkill> get skills => [SeerCheckSkill(), SpeakSkill(), VoteSkill()];

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
    if (skill is SeerCheckSkill) {
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
    WitchHealSkill(),
    WitchPoisonSkill(),
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
    if (skill is WitchHealSkill || skill is WitchPoisonSkill) {
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
  List<GameSkill> get skills => [HunterShootSkill(), SpeakSkill(), VoteSkill()];

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
    if (skill is HunterShootSkill) {
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
  String get rolePrompt => '''
你是守卫，在狼人杀游戏中属于好人阵营。
你每晚可以守护一名玩家，保护他们免受狼人击杀。
但要注意，你不能连续两晚守护同一名玩家。
请合理安排守护策略，保护重要的好人。
''';

  @override
  List<GameSkill> get skills => [
    GuardProtectSkill(),
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
    if (skill is GuardProtectSkill) {
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

/// 角色工厂类
class GameRoleFactory {
  static GameRole createRole(String roleId) {
    switch (roleId) {
      case 'villager':
        return VillagerRole();
      case 'werewolf':
        return WerewolfRole();
      case 'seer':
        return SeerRole();
      case 'witch':
        return WitchRole();
      case 'hunter':
        return HunterRole();
      case 'guard':
        return GuardRole();
      default:
        throw ArgumentError('Unknown role: $roleId');
    }
  }

  /// 根据角色类型创建角色实例
  static GameRole createRoleFromType(RoleType roleType) {
    switch (roleType) {
      case RoleType.villager:
        return VillagerRole();
      case RoleType.werewolf:
        return WerewolfRole();
      case RoleType.seer:
        return SeerRole();
      case RoleType.witch:
        return WitchRole();
      case RoleType.hunter:
        return HunterRole();
      case RoleType.guard:
        return GuardRole();
    }
  }

  static List<GameRole> createRolesFromConfig(Map<String, int> roleConfig) {
    final roles = <GameRole>[];
    roleConfig.forEach((roleId, count) {
      for (int i = 0; i < count; i++) {
        roles.add(createRole(roleId));
      }
    });
    return roles;
  }
}
