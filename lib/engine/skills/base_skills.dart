import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// 狼人击杀技能
class WerewolfKillSkill extends GameSkill {
  @override
  String get skillId => 'werewolf_kill';

  @override
  String get name => '狼人击杀';

  @override
  String get description => '夜晚可以击杀一名玩家';

  @override
  int get priority => 100; // 高优先级

  @override
  String get prompt => '''
现在是夜晚阶段，你需要和狼人队友讨论并选择击杀目标。
请考虑以下因素：
1. 谁最可能是神职？（预言家、女巫、守卫、猎人）
2. 谁对你的威胁最大？
3. 如何隐藏身份？
4. 如何制造混乱？

请和队友讨论后，共同决定今晚的击杀目标。
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && player.role.isWerewolf;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    // TODO: 实现狼人击杀逻辑
    // 这里暂时返回成功结果，具体实现在后续阶段完成
    return SkillResult.success(caster: player, metadata: {'skillId': skillId});
  }
}

/// 守卫保护技能
class GuardProtectSkill extends GameSkill {
  @override
  String get skillId => 'guard_protect';

  @override
  String get name => '守卫保护';

  @override
  String get description => '夜晚可以守护一名玩家';

  @override
  int get priority => 90; // 中等优先级

  @override
  String get prompt => '''
现在是夜晚阶段，请选择要守护的玩家。
请注意：
1. 你不能连续两晚守护同一名玩家
2. 守护可以保护玩家免受狼人击杀
3. 请仔细考虑谁最需要保护

请选择你的守护目标：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && player.role.roleId == 'guard';
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    // TODO: 实现守卫保护逻辑
    return SkillResult.success(caster: player, metadata: {'skillId': skillId});
  }
}

/// 预言家查验技能
class SeerCheckSkill extends GameSkill {
  @override
  String get skillId => 'seer_check';

  @override
  String get name => '预言家查验';

  @override
  String get description => '夜晚可以查验一名玩家的身份';

  @override
  int get priority => 80; // 中等优先级

  @override
  String get prompt => '''
现在是夜晚阶段，请选择要查验的玩家。
你可以通过查验了解玩家的真实身份（好人或狼人）。
请仔细选择查验目标，这个信息对好人阵营非常重要。

请选择你要查验的目标：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && player.role.roleId == 'seer';
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    // TODO: 实现预言家查验逻辑
    return SkillResult.success(caster: player, metadata: {'skillId': skillId});
  }
}

/// 女巫治疗技能
class WitchHealSkill extends GameSkill {
  @override
  String get skillId => 'witch_heal';

  @override
  String get name => '女巫解药';

  @override
  String get description => '可以救活被狼人击杀的玩家';

  @override
  int get priority => 85; // 高优先级

  @override
  String get prompt => '''
现在是夜晚阶段，你可以选择使用解药。
解药只能使用一次，可以救活今晚被狼人击杀的玩家。
请谨慎使用，因为解药用完后就无法再救人了。

是否要使用解药？
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive &&
        player.role.roleId == 'witch' &&
        player.role.hasPrivateData('has_antidote') != false;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    // TODO: 实现女巫治疗逻辑
    return SkillResult.success(caster: player, metadata: {'skillId': skillId});
  }
}

/// 女巫毒药技能
class WitchPoisonSkill extends GameSkill {
  @override
  String get skillId => 'witch_poison';

  @override
  String get name => '女巫毒药';

  @override
  String get description => '可以毒死一名玩家';

  @override
  int get priority => 95; // 高优先级

  @override
  String get prompt => '''
现在是夜晚阶段，你可以选择使用毒药。
毒药只能使用一次，可以直接毒死一名玩家。
请仔细选择目标，因为毒药用完后就无法再使用了。

请选择你要毒死的目标：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive &&
        player.role.roleId == 'witch' &&
        player.role.hasPrivateData('has_poison') != false;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    // TODO: 实现女巫毒药逻辑
    return SkillResult.success(caster: player, metadata: {'skillId': skillId});
  }
}

/// 猎人开枪技能
class HunterShootSkill extends GameSkill {
  @override
  String get skillId => 'hunter_shoot';

  @override
  String get name => '猎人开枪';

  @override
  String get description => '死亡时可以开枪带走一名玩家';

  @override
  int get priority => 110; // 最高优先级

  @override
  String get prompt => '''
你死亡了，但作为猎人，你可以在死前开枪带走一名玩家。
请选择你要击毙的目标。这是你最后的机会为好人阵营做贡献。

请选择你要开枪击毙的目标：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return !player.isAlive &&
        player.role.roleId == 'hunter' &&
        player.role.hasPrivateData('has_shot') != true;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    // TODO: 实现猎人开枪逻辑
    return SkillResult.success(caster: player, metadata: {'skillId': skillId});
  }
}

/// 发言技能（所有玩家都有）
class SpeakSkill extends GameSkill {
  @override
  String get skillId => 'speak';

  @override
  String get name => '发言';

  @override
  String get description => '在白天阶段进行发言';

  @override
  int get priority => 50; // 普通优先级

  @override
  String get prompt => '''
现在是白天讨论阶段，请进行你的发言。
你可以：
1. 分享昨晚的信息（如果你有的话）
2. 分析局势和推理
3. 表达你的怀疑对象
4. 为自己辩护或澄清

请发表你的观点：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && !player.isSilenced;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    // TODO: 实现发言逻辑
    return SkillResult.success(caster: player, metadata: {'skillId': skillId});
  }
}

/// 投票技能（所有玩家都有）
class VoteSkill extends GameSkill {
  @override
  String get skillId => 'vote';

  @override
  String get name => '投票';

  @override
  String get description => '投票出局一名玩家';

  @override
  int get priority => 60; // 普通优先级

  @override
  String get prompt => '''
现在是投票阶段，请选择你要投票出局的玩家。
请基于今天的讨论和你的分析进行投票。
记住，投票出局的玩家将被淘汰。

请选择你要投票的目标：
''';

  @override
  bool canCast(dynamic player, GameState state) {
    return player.isAlive && !player.isSilenced;
  }

  @override
  Future<SkillResult> cast(dynamic player, GameState state) async {
    // TODO: 实现投票逻辑
    return SkillResult.success(caster: player, metadata: {'skillId': skillId});
  }
}
