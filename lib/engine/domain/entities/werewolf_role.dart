import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/domain/enums/role_alignment.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/speak_skill.dart';
import 'package:werewolf_arena/engine/skills/vote_skill.dart';
import 'package:werewolf_arena/engine/skills/kill_skill.dart';
import 'package:werewolf_arena/engine/skills/werewolf_discuss_skill.dart';

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
  String get prompt => '''
你是狼人，是黑夜的猎手，是天生的演员。你的阵营只有你自己和你的狼队友们：【{teammates}】。
你的任务：
1.  【夜晚】：和队友沟通，选择一个最具威胁的好人进行袭击。
2.  【白天】：伪装成好人，通过发言迷惑他们，可以是悍跳预言家，也可以是倒钩站边真预言家，或者抱团攻击一个好人。
你的心法：胜利属于你们狼人集体。欺骗是你的本能，团队合作是你的利刃。保护你的队友，必要时甚至可以牺牲小我，换取团队的胜利。记住，整个村庄都是你的舞台，尽情表演吧。
''';

  @override
  List<GameSkill> get skills => [
    WerewolfDiscussSkill(),
    KillSkill(),
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
    if (skill is KillSkill) {
      return phase == GamePhase.night;
    } else if (skill is SpeakSkill) {
      return phase == GamePhase.day;
    } else if (skill is VoteSkill) {
      return phase == GamePhase.day;
    } else if (skill is WerewolfDiscussSkill) {
      return phase == GamePhase.night;
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
