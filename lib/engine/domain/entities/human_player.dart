import 'dart:async';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/state/game_state.dart';
import 'package:werewolf_arena/engine/events/base/game_event.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/drivers/player_driver.dart';
import 'package:werewolf_arena/engine/drivers/human_player_driver.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

/// 人类玩家实现
///
/// 使用HumanPlayerDriver等待人类输入的玩家实现
class HumanPlayer extends GamePlayer {
  @override
  final PlayerDriver driver = HumanPlayerDriver();

  final String _id;
  final String _name;
  final int _index;
  final GameRole _role;

  @override
  String get id => _id;
  @override
  String get name => _name;
  @override
  int get index => _index;
  @override
  GameRole get role => _role;

  bool _isAlive = true;
  bool _isProtected = false;
  bool _isSilenced = false;

  @override
  bool get isAlive => _isAlive;
  @override
  bool get isProtected => _isProtected;
  @override
  bool get isSilenced => _isSilenced;

  @override
  final Map<String, dynamic> privateData = {};

  @override
  final List<GameEvent> actionHistory = [];

  // StreamController用于外部UI提交技能结果
  final StreamController<SkillResult> _actionController =
      StreamController<SkillResult>.broadcast();

  HumanPlayer({
    required String id,
    required String name,
    required int index,
    required GameRole role,
  }) : _id = id,
       _name = name,
       _index = index,
       _role = role;

  /// 提供给外部UI调用的方法，用于提交技能执行结果
  void submitSkillResult(SkillResult result) {
    if (!_actionController.isClosed) {
      _actionController.add(result);
    }
  }

  /// 取消当前等待的技能输入
  void cancelSkillInput() {
    if (!_actionController.isClosed) {
      _actionController.add(
        SkillResult.failure(
          caster: this,
          metadata: {'reason': 'Cancelled by user'},
        ),
      );
    }
  }

  @override
  Future<SkillResult> executeSkill(GameSkill skill, GameState state) async {
    if (!skill.canCast(this, state)) {
      return SkillResult.failure(
        caster: this,
        metadata: {'reason': 'Cannot cast skill', 'skillId': skill.skillId},
      );
    }

    try {
      // 使用Driver处理技能响应（通常是等待人类输入）
      final response = await driver.generateSkillResponse(
        player: this,
        state: state,
        skillPrompt: skill.prompt,
        expectedFormat: _getExpectedFormat(skill),
      );

      // 调用技能的cast方法
      final result = await skill.cast(this, state);

      // 记录技能使用
      useSkill(skill.skillId);
      // 不需要添加action，因为skill.cast已经处理了事件

      return result;
    } catch (e) {
      return SkillResult.failure(
        caster: this,
        metadata: {'error': e.toString(), 'skillId': skill.skillId},
      );
    }
  }

  @override
  void onGameEvent(GameEvent event) {
    // 人类玩家处理游戏事件，通常用于UI更新
    // 可以在这里触发UI更新事件
  }

  @override
  void onDeath(DeathCause cause) {
    _isAlive = false;
    setPrivateData('death_cause', cause);
    setPrivateData('death_day', privateData['current_day'] ?? 0);
  }

  @override
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase) {
    setPrivateData('last_phase', oldPhase);
    setPrivateData('current_phase', newPhase);

    // 重置阶段相关状态
    if (newPhase == GamePhase.night) {
      _isProtected = false;
      _isSilenced = false;
    }
  }

  @override
  bool canAct(GamePhase phase) {
    if (!isAlive) return false;
    if (isSilenced && phase == GamePhase.day) return false;
    return true;
  }

  @override
  bool canVote() {
    return isAlive && !isSilenced;
  }

  @override
  bool canSpeak() {
    return isAlive && !isSilenced;
  }

  @override
  void setAlive(bool alive) {
    _isAlive = alive;
  }

  @override
  void setProtected(bool protected) {
    _isProtected = protected;
  }

  @override
  void setSilenced(bool silenced) {
    _isSilenced = silenced;
  }

  @override
  int getSkillUses(String skillId) {
    return privateData['skill_uses_$skillId'] ?? 0;
  }

  @override
  void useSkill(String skillId) {
    privateData['skill_uses_$skillId'] = getSkillUses(skillId) + 1;
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
  void addAction(GameEvent action) {
    actionHistory.add(action);
  }

  @override
  void addKnowledge(String key, dynamic value) {
    final knowledge = getPrivateData<Map<String, dynamic>>('knowledge') ?? {};
    knowledge[key] = value;
    setPrivateData('knowledge', knowledge);
  }

  @override
  T? getKnowledge<T>(String key) {
    final knowledge = getPrivateData<Map<String, dynamic>>('knowledge') ?? {};
    return knowledge[key] as T?;
  }

  @override
  bool hasKnowledge(String key) {
    final knowledge = getPrivateData<Map<String, dynamic>>('knowledge') ?? {};
    return knowledge.containsKey(key);
  }

  @override
  String getStatus() {
    return '$name (${isAlive ? 'Alive' : 'Dead'}) - ${role.name} [Human]';
  }

  @override
  String get formattedName =>
      '[${name.padLeft(5)}|${role.name.padLeft(4)}|Human]';

  @override
  void die(DeathCause cause, GameState state) {
    onDeath(cause);
    // 注意：GameState.playerDeath需要Player类型，这里需要在后续重构中统一
    // state.playerDeath(this, cause);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'index': index,
      'role': role.toJson(),
      'type': 'human',
      'isAlive': isAlive,
      'isProtected': isProtected,
      'isSilenced': isSilenced,
      'privateData': Map<String, dynamic>.from(privateData),
      'actionHistory': actionHistory.map((e) => e.toJson()).toList(),
    };
  }

  /// 获取技能的期望格式
  String _getExpectedFormat(GameSkill skill) {
    // 为人类玩家提供技能输入格式指导
    if (skill.skillId.contains('kill') || skill.skillId.contains('attack')) {
      return '选择要击杀的目标玩家';
    } else if (skill.skillId.contains('protect') ||
        skill.skillId.contains('guard')) {
      return '选择要保护的目标玩家';
    } else if (skill.skillId.contains('investigate') ||
        skill.skillId.contains('check')) {
      return '选择要查验的目标玩家';
    } else if (skill.skillId.contains('vote')) {
      return '选择要投票的目标玩家';
    } else if (skill.skillId.contains('speak')) {
      return '输入你的发言内容';
    } else {
      return '选择目标或输入内容';
    }
  }

  /// 释放资源
  void dispose() {
    if (!_actionController.isClosed) {
      _actionController.close();
    }
  }
}
