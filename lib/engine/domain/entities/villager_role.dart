import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/domain/enums/role_alignment.dart';
import 'package:werewolf_arena/engine/domain/enums/role_type.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/speak_skill.dart';
import 'package:werewolf_arena/engine/skills/vote_skill.dart';

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
  String get prompt => '''
你是一名普通村民。你没有特殊的技能，但你拥有最强大的武器：逻辑和投票权。你是好人阵营的基石。
你的任务：在白天的发言中，仔细倾听每个人的发言，分辨真伪，找出言行不一的玩家。
你的心法：虽然你是“闭眼玩家”，信息最少，但这也让你最不容易被狼人针对。你的发言要真诚，逻辑要清晰。当你坚信某人是狼时，要果断地投出你的一票。你的每一票，都在为好人阵营的胜利添砖加瓦。活下去，活到最后，用投票清理所有坏人。
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
