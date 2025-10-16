import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import 'package:werewolf_arena/engine/domain/entities/game_role.dart';
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/events/game_event.dart';
import 'package:werewolf_arena/engine/domain/value_objects/death_cause.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_phase.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_event_type.dart';
import 'package:werewolf_arena/engine/drivers/player_driver.dart';
import 'package:werewolf_arena/engine/drivers/ai_player_driver.dart';
import 'package:werewolf_arena/engine/domain/value_objects/game_config.dart';
import 'package:werewolf_arena/engine/skills/game_skill.dart';
import 'package:werewolf_arena/engine/skills/skill_result.dart';

/// AI玩家实现
///
/// 使用AIPlayerDriver进行AI决策的玩家实现
class AIPlayer extends GamePlayer {
  @override
  final PlayerDriver driver;

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

  AIPlayer({
    required String id,
    required String name,
    required int index,
    required GameRole role,
    required PlayerIntelligence intelligence,
  }) : _id = id,
       _name = name,
       _index = index,
       _role = role,
       driver = AIPlayerDriver(intelligence: intelligence);

  @override
  Future<SkillResult> executeSkill(GameSkill skill, GameState state) async {
    try {
      // 使用Driver生成技能响应
      final response = await driver.request(
        player: this,
        state: state,
        skillPrompt: skill.prompt,
      );
      return SkillResult(
        caster: name,
        target: response.target,
        message: response.message,
        reasoning: response.reasoning,
      );
    } catch (e) {
      return SkillResult(caster: name);
    }
  }

  @override
  void onGameEvent(GameEvent event) {
    // AI处理游戏事件，更新知识库
    _updateKnowledgeFromEvent(event);
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

  // 为测试添加的便利方法
  @override
  set isDead(bool dead) {
    _isAlive = !dead;
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
    return '$name (${isAlive ? 'Alive' : 'Dead'}) - ${role.name} [AI]';
  }

  @override
  String get formattedName => '[${name.padLeft(5)}|${role.name.padLeft(4)}|AI]';

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
      'type': 'ai',
      'isAlive': isAlive,
      'isProtected': isProtected,
      'isSilenced': isSilenced,
      'privateData': Map<String, dynamic>.from(privateData),
      'actionHistory': actionHistory.map((e) => e.toJson()).toList(),
    };
  }

  /// 从事件更新知识库
  void _updateKnowledgeFromEvent(GameEvent event) {
    // 更新AI的知识基于收到的事件
    addKnowledge('last_event_type', event.type);
    addKnowledge('event_count', (getKnowledge<int>('event_count') ?? 0) + 1);

    // 根据事件类型更新特定知识
    switch (event.type) {
      case GameEventType.playerDeath:
        final deadPlayerCount = getKnowledge<int>('dead_player_count') ?? 0;
        addKnowledge('dead_player_count', deadPlayerCount + 1);
        break;
      case GameEventType.phaseChange:
        addKnowledge('last_phase_change', event.type);
        break;
      default:
        // 记录其他类型事件的发生
        break;
    }
  }
}
