# Werewolf Arena 游戏引擎架构升级文档

## 文档信息
- **版本**: 2.0.0
- **日期**: 2025-10-10
- **目标**: 重构游戏引擎，实现真正的职责分离和自洽运行

## 1. 升级背景

### 当前架构问题
当前的 `GameParameters` 接口存在严重的职责混乱问题：

```dart
abstract class GameParameters {
  AppConfig get config;                              // 应用配置
  ScenarioRegistry get scenarioRegistry;             // 场景注册表
  GameScenario? get currentScenario;                 // 当前场景
  Future<void> initialize();                         // 初始化系统
  Future<void> saveConfig(AppConfig newConfig);      // 保存配置
  void setCurrentScenario(String scenarioId);        // 设置场景
  List<GameScenario> getAvailableScenarios(int playerCount); // 查询场景
  Map<String, dynamic> getPlayerLLMConfig(int playerNumber);  // LLM配置
}
```

**问题分析**:
- **职责混乱**: 参数容器、配置管理、场景管理、查询服务混杂
- **接口臃肿**: 违反接口隔离原则，实现类必须实现所有方法
- **概念混淆**: GameParameters 名字暗示参数容器，实际是"万能管理器"
- **测试困难**: 需要模拟大量不相关的方法

### 设计理念转变
**新的设计理念**:
- **游戏引擎是纯粹的游戏逻辑执行器**
- **获得必要信息后，能够自洽地运转游戏**
- **通过Observer模式与外界交互**
- **不关心配置如何加载、场景如何选择、玩家如何创建**

## 2. 核心架构重构

### 2.1 游戏引擎接口简化

**重构前**:
```dart
GameEngine({
  required this.parameters,  // 复杂的GameParameters接口
  GameObserver? observer,
});
```

**重构后**:
```dart
class GameEngine {
  // === 外部输入 ===
  final GameConfig config;
  final GameScenario scenario;
  final List<GamePlayer> players;
  final GameObserver? _observer;
  
  // === 核心状态 ===
  GameState? _currentState;
  GameStatus _status = GameStatus.waiting;
  
  // === 阶段处理器 ===
  final NightPhaseProcessor _nightProcessor;
  final DayPhaseProcessor _dayProcessor;
  
  // === 工具类 ===
  final GameRandom _random;
  
  GameEngine({
    required this.config,
    required this.scenario,
    required this.players,
    GameObserver? observer,
  }) : _observer = observer,
       _random = GameRandom(),
       _nightProcessor = NightPhaseProcessor(),
       _dayProcessor = DayPhaseProcessor();
}
```

### 2.2 三个核心类的职责重新定义

#### 2.2.1 GameConfig - 游戏配置
**职责**: 提供游戏引擎运行所必需的技术参数

```dart
class GameConfig {
  // 玩家智能配置
  final List<PlayerIntelligence> playerIntelligences;
  final int maxRetries;
  
  GameConfig({
    required this.playerIntelligences,
    required this.maxRetries,
  });
  
  // 获取指定玩家的智能
  PlayerIntelligence? getPlayerIntelligence(int playerIndex) {
    if (playerIndex < 1 || playerIndex > playerIntelligences.length) {
      return null;
    }
    return playerIntelligences[playerIndex - 1];
  }
  
  // 获取默认智能（第一个玩家）
  PlayerIntelligence? get defaultIntelligence => playerIntelligences.isNotEmpty ? playerIntelligences.first : null;
}

// 玩家智能配置
class PlayerIntelligence {
  final String baseUrl;
  final String apiKey;
  final String modelId;
  
  PlayerIntelligence({
    required this.baseUrl,
    required this.apiKey,
    required this.modelId,
  });
  
  // 创建副本用于修改
  PlayerIntelligence copyWith({
    String? baseUrl,
    String? apiKey,
    String? modelId,
  }) {
    return PlayerIntelligence(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      modelId: modelId ?? this.modelId,
    );
  }
}
```

**设计原则**:
- 只包含游戏引擎**必需**的配置
- `playerIntelligences` 数组按玩家索引存储，1号玩家对应index 0
- `maxRetries` 控制AI服务失败时的最大重试次数
- 每个玩家的智能包含完整的连接信息

#### 2.2.2 GameScenario - 游戏场景
**职责**: 定义游戏规则、角色配置和胜利条件

**接口优化**:
```dart
abstract class GameScenario {
  // 基本信息
  String get id;
  String get name;
  String get description;
  int get playerCount;
  
  // 游戏规则（给用户看）
  String get rule;                           // 游戏规则说明，供玩家查看
  
  // 角色配置
  Map<RoleType, int> get roleDistribution;
  
  // 核心方法
  List<RoleType> getExpandedRoles();          // 获取角色列表
  Role createRole(RoleType roleType);        // 创建角色实例
  VictoryResult checkVictoryCondition(GameState state); // 检查胜利条件
  
  // 移除的方法（不再需要）
  // void initialize(GameState gameState);     // 游戏引擎自己处理
  // String? getNextActionRole(...);          // 游戏引擎自己处理
}
```

**设计原则**:
- 专注于游戏规则定义
- 不参与游戏流程控制
- 提供必要的游戏规则查询
- 为玩家提供清晰的规则说明
- 便于在游戏界面中展示给用户查看
- rule字段用于向不熟悉该板子的用户解释规则

**实现示例**:
```dart
class Scenario9Players implements GameScenario {
  @override
  String get id => 'standard_9_players';
  
  @override
  String get name => '标准9人局';
  
  @override
  String get description => '经典狼人杀9人局配置';
  
  @override
  int get playerCount => 9;
  
  @override
  String get rule => '''
标准狼人杀游戏规则：

游戏目标：
- 好人阵营：消灭所有狼人
- 狼人阵营：狼人数量≥好人数量

游戏流程：
1. 夜晚阶段：狼人击杀、守卫守护、预言家查验、女巫用药
2. 白天阶段：公布结果、玩家发言讨论
3. 投票阶段：投票出局玩家，若平票则PK

角色能力：
- 狼人：夜晚可以击杀一名玩家
- 村民：无特殊能力
- 预言家：夜晚可以查验一名玩家身份
- 女巫：拥有一瓶解药和一瓶毒药
- 守卫：夜晚可以守护一名玩家（不能连续守护同一人）
- 猎人：被投票出局或被狼人击杀时可以开枪带走一名玩家

特殊规则：
- 女巫的解药和毒药不能在同一晚使用
- 守卫不能连续两晚守护同一玩家
- 猎人只有在被投票出局或被狼人击杀时才能开枪
- 平票时进入PK环节，平票玩家发言后重新投票
''';

  @override
  Map<RoleType, int> get roleDistribution => {
    RoleType.werewolf: 2,
    RoleType.villager: 3,
    RoleType.seer: 1,
    RoleType.witch: 1,
    RoleType.guard: 1,
    RoleType.hunter: 1,
  };

  @override
  List<RoleType> getExpandedRoles() {
    final roles = <RoleType>[];
    roleDistribution.forEach((role, count) {
      for (int i = 0; i < count; i++) {
        roles.add(role);
      }
    });
    return roles;
  }

  @override
  Role createRole(RoleType roleType) {
    switch (roleType) {
      case RoleType.werewolf:
        return WerewolfRole();
      case RoleType.villager:
        return VillagerRole();
      case RoleType.seer:
        return SeerRole();
      case RoleType.witch:
        return WitchRole();
      case RoleType.guard:
        return GuardRole();
      case RoleType.hunter:
        return HunterRole();
      default:
        throw Exception('Unknown role type: $roleType');
    }
  }

  @override
  VictoryResult checkVictoryCondition(GameState state) {
    final aliveWerewolves = state.aliveWerewolves;
    final aliveGoodGuys = state.aliveGoodGuys;
    
    if (aliveWerewolves == 0) {
      return VictoryResult(winner: '好人阵营', reason: '所有狼人已被消灭');
    }
    
    if (aliveWerewolves >= aliveGoodGuys) {
      return VictoryResult(winner: '狼人阵营', reason: '狼人数量≥好人数量');
    }
    
    return VictoryResult(winner: null, reason: '游戏继续');
  }
}
```

#### 2.2.3 GamePlayer - 游戏玩家
**职责**: 代表游戏参与者，管理个人状态和行动能力，每个玩家拥有自己的Driver

**抽象基类设计**:
```dart
abstract class GamePlayer {
  // 基本属性
  String get id;
  String get name;
  int get index;                    // 玩家序号（1号玩家、2号玩家等）
  GameRole get role;
  
  // 每个玩家有自己的Driver
  PlayerDriver get driver;
  
  // 状态
  bool get isAlive;
  bool get isProtected;
  bool get isSilenced;
  
  // 核心方法 - 通过自己的Driver执行技能
  Future<SkillResult> executeSkill(GameSkill skill, GameState state);
  
  // 事件处理
  void onGameEvent(GameEvent event);
  void onDeath(DeathCause cause);
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase);
  
  // 状态检查
  bool canAct(GamePhase phase);
  bool canVote();
  bool canSpeak();
}
```

**AI玩家实现**:
```dart
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
    return await skill.cast(state, SkillContext(player: this));
  }
  
  @override
  void onGameEvent(GameEvent event) {
    // 处理游戏事件
  }
  
  @override
  void onDeath(DeathCause cause) {
    _isAlive = false;
  }
  
  @override
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase) {
    // 处理阶段变化
  }
  
  @override
  bool canAct(GamePhase phase) {
    return isAlive && !isSilenced;
  }
  
  @override
  bool canVote() {
    return isAlive;
  }
  
  @override
  bool canSpeak() {
    return isAlive && !isSilenced;
  }
}
```

**人类玩家实现**:
```dart
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
  
  final StreamController<SkillResult> _actionController;
  
  HumanPlayer({
    required String id,
    required String name,
    required int index,
    required GameRole role,
  }) : _id = id,
       _name = name,
       _index = index,
       _role = role,
       _actionController = StreamController<SkillResult>.broadcast();
  
  // 提供给外部UI调用的方法
  void submitSkillResult(SkillResult result) {
    _actionController.add(result);
  }
  
  @override
  Future<SkillResult> executeSkill(GameSkill skill, GameState state) async {
    // 等待人类用户通过UI输入技能执行结果
    return await _actionController.stream.firstWhere(
      (result) => result.caster == this,
    );
  }
  
  @override
  void onGameEvent(GameEvent event) {
    // 处理游戏事件
  }
  
  @override
  void onDeath(DeathCause cause) {
    _isAlive = false;
  }
  
  @override
  void onPhaseChange(GamePhase oldPhase, GamePhase newPhase) {
    // 处理阶段变化
  }
  
  @override
  bool canAct(GamePhase phase) {
    return isAlive && !isSilenced;
  }
  
  @override
  bool canVote() {
    return isAlive;
  }
  
  @override
  bool canSpeak() {
    return isAlive && !isSilenced;
  }
  
  void dispose() {
    _actionController.close();
  }
}
```

**设计优势**:
- **消除枚举**：不再需要 `PlayerType` 枚举，通过类的继承关系体现玩家类型
- **真正的多态**：通过方法重写而不是条件判断来区分行为
- **每个玩家有自己的Driver**：AI玩家使用AIPlayerDriver，人类玩家使用HumanPlayerDriver
- **职责明确**：每个Driver只负责驱动一个玩家，配置完全独立
- **更好的扩展性**：新增玩家类型只需添加新的 `GamePlayer` 子类和对应的Driver
- **类型安全**：使用 `is` 操作符进行类型检查：`if (player is AIPlayer)`

#### 2.2.4 GameRole - 游戏角色
**职责**: 定义角色能力、技能和行为，成为完整的角色实体

**接口设计**:
```dart
abstract class GameRole {
  // 基础信息
  String get roleId;
  String get name;
  String get description;
  RoleAlignment get alignment;
  
  // 角色身份提示词
  String get rolePrompt;           // 定义角色身份和阵营目标
  
  // 技能系统
  List<GameSkill> get skills;      // 角色拥有的技能列表
  List<GameSkill> getAvailableSkills(GamePhase phase);  // 获取指定阶段可用技能
  
  // 角色属性
  bool get isWerewolf;
  bool get isVillager;
  bool get isGod;
  
  // 事件响应
  void onGameStart(GameState state);
  void onNightStart(GameState state);
  void onDayStart(GameState state);
  void onDeath(GamePlayer player, DeathCause cause);
}
```

**设计原则**:
- 角色包含自己的技能列表，技能代表角色的所有能力
- 通过技能系统统一处理所有游戏行为
- 技能的可用性由游戏流程和角色共同决定
- GameRole定义角色身份，GameSkill定义具体行为和Prompt

**GameRole实现示例**:
```dart
class WerewolfGameRole implements GameRole {
  @override
  String get roleId => 'werewolf';
  
  @override
  String get name => '狼人';
  
  @override
  String get description => '夜晚可以击杀一名玩家的邪恶角色';
  
  @override
  RoleAlignment get alignment => RoleAlignment.evil;
  
  @override
  bool get isWerewolf => true;
  
  @override
  bool get isVillager => false;
  
  @override
  bool get isGod => false;
  
  @override
  List<GameSkill> get skills => [
    WerewolfKillSkill(),    // 狼人击杀技能
    WerewolfDiscussSkill(), // 狼人讨论技能
  ];
  
  @override
  List<GameSkill> getAvailableSkills(GamePhase phase) {
    return skills.where((skill) => 
      canUseSkillInPhase(skill, phase)
    ).toList();
  }
  
  bool canUseSkillInPhase(GameSkill skill, GamePhase phase) {
    if (skill is WerewolfKillSkill || skill is WerewolfDiscussSkill) {
      return phase == GamePhase.night;
    }
    return false;
  }
  
  @override
  String get rolePrompt => '''
你是一个狼人，在狼人杀游戏中属于狼人阵营。
你的目标是与队友合作，消灭所有好人。
''';

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
  void onDeath(GamePlayer player, DeathCause cause) {
    // 狼人死亡时的逻辑
  }
}
```

### 2.3 游戏引擎的内部组件

#### 2.3.1 核心状态管理
- **GameState** - 游戏整体状态，包含玩家、事件历史等
- **GameStatus** - 游戏状态（等待、进行中、已结束）

#### 2.3.2 阶段处理器
- **NightPhaseProcessor** - 夜晚阶段处理器
- **DayPhaseProcessor** - 白天阶段处理器（包含发言和投票）

#### 2.3.3 工具类
- **GameRandom** - 随机数生成工具

### 2.4 技能系统架构

#### 2.4.1 技能抽象接口
**设计理念**: 将所有游戏行为统一为技能系统，包括夜晚行动、白天发言、投票等

```dart
abstract class GameSkill {
  // 技能基本信息
  String get skillId;
  String get name;
  String get description;
  int get priority;          // 技能优先级，用于决定执行顺序
  
  // 技能提示词
  String get prompt;              // 技能的行动指导提示词
  
  // 技能核心方法
  bool canCast(GamePlayer player, GameState state);  // 是否可以施放技能
  Future<SkillResult> cast(GamePlayer player, GameState state);  // 施放技能
}

// 技能结果
class SkillResult {
  final bool success;
  final GamePlayer caster;
  final GamePlayer? target;
  
  SkillResult({
    required this.success,
    required this.caster,
    this.target,
  });
}
```

#### 2.4.2 具体技能实现示例
```dart
// 狼人击杀技能
class WerewolfKillSkill extends GameSkill {
  @override
  String get skillId => 'werewolf_kill';
  @override
  String get name => '狼人击杀';
  @override
  String get description => '夜晚可以击杀一名玩家';
  @override
  int get priority => 100;  // 高优先级
  
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
  bool canCast(GamePlayer player, GameState state) {
    return player.isAlive && player.role.isWerewolf;
  }
  
  @override
  Future<SkillResult> cast(GamePlayer player, GameState state) async {
    // 生成内部决策事件（只有狼人可见）
    state.addEvent(WerewolfDecisionEvent(
      werewolf: player,
      content: '${player.name}正在选择击杀目标',
    ));
    
    // 直接从state获取可用目标
    final availableTargets = state.alivePlayers.where((p) => p != player && !p.role.isWerewolf).toList();
    
    // 使用玩家的Driver决策目标，结合技能提示词
    final jsonResult = await player.driver.generateSkillResponse(
      player: player,
      state: state,
      skillPrompt: prompt,
      expectedFormat: '''
{
  "target": "目标玩家名称",
  "reasoning": "选择理由"
}
''',
    );
    
    final targetName = jsonResult['target'];
    final target = state.getPlayerByName(targetName);
    
    // 生成内部选择结果事件（只有狼人可见）
    if (target != null) {
      state.addEvent(WerewolfTargetSelectedEvent(
        werewolf: player,
        target: target,
        content: '${player.name}选择了击杀${target.name}',
      ));
    }
    
    // 直接应用效果，不需要SkillEffect
    if (target != null) {
      state.playerDeath(target, DeathCause.werewolfKill);
    }
    
    return SkillResult(
      success: target != null,
      caster: player,
      target: target,
    );
  }
}

// 守卫保护技能
class GuardProtectSkill extends GameSkill {
  @override
  String get skillId => 'guard_protect';
  @override
  String get name => '守卫保护';
  @override
  String get description => '夜晚可以守护一名玩家';
  @override
  int get priority => 90;  // 中等优先级
  
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
  bool canCast(GamePlayer player, GameState state) {
    return player.isAlive && player.role.roleId == 'guard';
  }
  
  @override
  Future<SkillResult> cast(GamePlayer player, GameState state) async {
    // 直接从state获取可用目标，排除上次守护的玩家
    final lastProtected = state.nightActions.tonightProtected;
    final availableTargets = state.alivePlayers
        .where((p) => p != player && p != lastProtected)
        .toList();
    
    // 使用玩家的Driver决策保护目标，使用技能的提示词
    final jsonResult = await player.driver.generateSkillResponse(
      player: player,
      state: state,
      skillPrompt: prompt,
      expectedFormat: '''
{
  "target": "目标玩家名称",
  "reasoning": "选择理由"
}
''',
    );
    
    final targetName = jsonResult['target'];
    final target = state.getPlayerByName(targetName);
    
    // 直接应用效果，设置保护目标
    if (target != null) {
      state.nightActions.setTonightProtected(target);
    }
    
    return SkillResult(
      success: target != null,
      caster: player,
      target: target,
    );
  }
}
```

#### 2.4.3 技能处理器
```dart
class SkillProcessor {
  // 处理技能结果和冲突
  void process(List<SkillResult> results, GameState state) {
    // 处理保护vs击杀冲突
    final killResults = results.where((r) => r.success && r.target != null).toList();
    final protectResults = results.where((r) => r.success && r.target != null).toList();
    
    // 检查是否有击杀目标被保护
    for (final killResult in killResults) {
      if (protectResults.any((protectResult) => protectResult.target == killResult.target)) {
        // 击杀被保护抵消，撤销击杀效果
        if (killResult.target != null) {
          state.cancelPlayerDeath(killResult.target!);
        }
      }
    }
  }
}
```

#### 2.4.4 阶段处理器重构
```dart
class NightPhaseProcessor implements PhaseProcessor {
  final SkillProcessor _skillProcessor = SkillProcessor();
  
  @override
  Future<void> process(GameState state) async {
    // 1. 阶段开始事件（所有人可见）
    state.addEvent(PhaseStartEvent(
      phase: GamePhase.night,
      content: '夜晚来临，请所有玩家闭眼',
    ));
    
    // 2. 收集当前阶段可用技能
    final availableSkills = <GameSkill>[];
    for (final player in state.alivePlayers) {
      final playerSkills = player.role.getAvailableSkills(GamePhase.night);
      availableSkills.addAll(playerSkills);
    }
    
    // 3. 按优先级排序并执行技能
    availableSkills.sort((a, b) => a.priority.compareTo(b.priority));
    final skillResults = await _executeSkills(state, availableSkills);
    
    // 4. SkillProcessor结算所有技能结果和冲突
    await _skillProcessor.process(skillResults, state);
    
    // 5. 生成夜晚结果事件（所有人可见）
    _generateNightResultEvents(state, skillResults);
    
    // 6. 阶段结束事件（所有人可见）
    state.addEvent(PhaseEndEvent(
      phase: GamePhase.night,
      content: '夜晚结束',
    ));
  }
  
  Future<List<SkillResult>> _executeSkills(
    GameState state, 
    List<GameSkill> availableSkills
  ) async {
    final results = <SkillResult>[];
    
    for (final skill in availableSkills) {
      // 找到技能的拥有者
      final player = state.players.firstWhere(
        (p) => p.role.skills.contains(skill),
      );
      
      // 直接使用player和state，不需要SkillContext
      if (skill.canCast(player, state)) {
        final result = await skill.cast(player, state);
        results.add(result);
      }
    }
    
    return results;
  }
  
  void _generateNightResultEvents(GameState state, List<SkillResult> results) {
    // 从state中获取今晚的死亡结果，而不是从SkillResult中
    final tonightDeaths = state.deadPlayers.where((p) => 
      state.eventHistory.any((event) => 
        event is DeadEvent && 
        event.victim == p && 
        event.dayNumber == state.dayNumber &&
        event.cause == DeathCause.werewolfKill
      )
    ).toList();
    
    if (tonightDeaths.isEmpty) {
      // 平安夜
      state.addEvent(NightResultEvent(
        resultType: 'peaceful',
        content: '平安夜，无人死亡',
      ));
    } else {
      // 有人死亡
      for (final victim in tonightDeaths) {
        state.addEvent(NightResultEvent(
          resultType: 'death',
          victim: victim,
          content: '${victim.name}死亡',
        ));
      }
    }
  }
}
```

#### 2.4.5 技能系统设计优势

1. **概念统一**: 所有游戏行为都是技能，消除概念碎片化
2. **职责分离**: 
   - GameRole定义角色身份和基础目标
   - GameSkill定义具体行为和专用提示词
   - 阶段处理器负责流程控制
   - SkillProcessor负责效果结算
3. **事件分层**:
   - 技能内部生成私有事件（对自己或特定角色可见）
   - 阶段处理器生成公开事件（全局可见）
4. **提示词优化**: 角色提示词和技能提示词分离，职责更清晰
5. **每个玩家有自己的Driver**: 配置完全独立，职责明确
6. **Driver接口统一**: 所有技能都通过相同的`generateSkillResponse`方法调用
7. **简化设计**: 移除了不必要的SkillContext、SkillEffect和metadata抽象层
8. **直接操作**: 技能可以直接访问GameState，获取所需信息
9. **即时生效**: 技能效果直接应用，无需额外的效果对象
10. **结果简洁**: SkillResult只包含核心信息，避免过度设计
11. **易于扩展**: 新增角色或能力只需实现对应技能类
12. **优先级控制**: 通过priority属性明确技能执行顺序
13. **冲突处理**: 统一的冲突解决机制

### 2.5 删除的类

#### 删除的类:
- **`GameParameters`** - 职责混乱的接口
- **`ScenarioRegistry`** - 游戏引擎不关心场景管理
- **`PlayerType`** - 不再需要，通过类的继承关系体现玩家类型
- **外部服务类** - action_resolver_service、event_filter_service、player_order_service
- **`LLMClient`** - 不需要的抽象，直接使用用户现有的OpenAIService
- **Action相关类** - 被技能系统取代
- **NightActionState** - 夜晚行动被技能系统取代
- **VotingState** - 投票被VoteSkill技能取代
- **VotingPhaseProcessor** - 投票合并到白天阶段
- **PlayerStateManager** - 玩家状态由GamePlayer自己管理
- **ActionValidator** - 被技能系统的canCast方法取代
- **StreamController** - 过度设计的事件流机制，GameObserver足够
- **SkillContext** - GameState已包含所有必要信息
- **SkillEffect** - 技能效果可以直接应用，无需额外抽象层
- **SkillResult.metadata** - 过度设计，结果应只包含核心信息

#### 重命名的类:
- **`Player`** → **`GamePlayer`** - 统一命名规范，改为抽象基类
- **`Role`** → **`GameRole`** - 统一命名规范，整合Prompt系统和技能系统
- **`LLMService`** → **`PlayerDriver`** - 更好地反映其作为AI玩家驱动器的本质

#### PlayerDriver架构简化:
- **原设计**: 一个PlayerDriver管理多个玩家的OpenAIService实例
- **新设计**: 每个GamePlayer拥有自己的PlayerDriver实例
- **优势**: 配置完全独立，职责更明确，每个Driver只负责一个玩家

#### 重构的类:
- **`GamePlayer`** - 从接口改为抽象基类，新增AIPlayer和HumanPlayer实现
- **`GameScenario`** - 专注于规则定义，添加用户友好的rule字段
- **`GameEngine`** - 大幅简化，只保留核心状态和3个阶段处理器
- **`GameRole`** - 整合Prompt系统和技能列表，成为完整的角色实体
- **阶段处理器** - 重构为基于技能系统的处理器，移除Map管理
- **SkillResult** - 简化设计，只包含核心信息：success、caster、target

## 3. 游戏流程重构

### 3.1 外部组装器模式

**新的游戏启动流程**:
```dart
class GameAssembler {
  static Future<GameEngine> assembleGame({
    String? configPath,
    String? scenarioId,
    int? playerCount,
    GameObserver? observer,
  }) async {
    // 1. 外部逻辑：加载配置
    final config = await _loadConfig(configPath);
    
    // 2. 外部逻辑：选择场景
    final scenario = await _selectScenario(scenarioId, playerCount);
    
    // 3. 外部逻辑：创建玩家
    final gamePlayers = await _createGamePlayers(scenario, config);
    
    // 4. 创建游戏引擎
    return GameEngine(
      config: config,
      scenario: scenario,
      players: gamePlayers,
      observer: observer,
    );
  }
}
```

### 3.2 游戏引擎的自洽运行

**游戏引擎内部流程**:
```dart
class GameEngine {
  // === 核心方法 ===
  Future<void> initializeGame() async {
    // 创建游戏状态
    _currentState = GameState(
      gameId: 'game_${DateTime.now().toString()}',
      config: config,
      scenario: scenario,
      players: players,
    );
    
    // 初始化游戏
    _currentState!.startGame();
    _status = GameStatus.waiting;
    
    // 通知状态更新
    _observer?.onStateChange(_currentState!);
  }
  
  // === 游戏流程控制 ===
  Future<void> executeGameStep() async {
    if (!isGameRunning || isGameEnded) return;
    
    try {
      // 根据当前阶段选择对应的处理器
      final processor = switch (_currentState!.currentPhase) {
        GamePhase.night => _nightProcessor,
        GamePhase.day => _dayProcessor,
      };
      
      // 执行阶段处理
      await processor.process(_currentState!);
      
      // 通知状态更新
      _observer?.onStateChange(_currentState!);
      
      // 检查游戏结束
      if (_currentState!.checkGameEnd()) {
        await _endGame();
      }
    } catch (e) {
      await _handleGameError(e);
    }
  }
  
  // === 状态查询 ===
  GameState? get currentState => _currentState;
  GameStatus get status => _status;
  bool get hasGameStarted => _currentState != null;
  bool get isGameRunning => hasGameStarted && _status == GameStatus.playing;
  bool get isGameEnded => hasGameStarted && _status == GameStatus.ended;
}
```


### 3.3 PlayerDriver设计

PlayerDriver是每个GamePlayer内部持有的组件，负责为玩家生成AI决策。

#### PlayerDriver架构
```dart
abstract class PlayerDriver {
  // 核心方法：为玩家生成技能响应
  Future<Map<String, dynamic>> generateSkillResponse({
    required GamePlayer player,
    required GameState state,
    required String skillPrompt,
    required String expectedFormat,
  });
}

// AI玩家驱动器
class AIPlayerDriver implements PlayerDriver {
  final PlayerIntelligence intelligence;
  final OpenAIService _service;
  
  AIPlayerDriver({required this.intelligence}) 
      : _service = OpenAIService(
          apiKey: intelligence.apiKey,
          model: intelligence.modelId,
          baseUrl: intelligence.baseUrl,
          retryConfig: RetryConfig(maxAttempts: 3),
        );
  
  @override
  Future<Map<String, dynamic>> generateSkillResponse({
    required GamePlayer player,
    required GameState state,
    required String skillPrompt,
    required String expectedFormat,
  }) async {
    final fullPrompt = '''
${skillPrompt}

请严格按照以下JSON格式返回结果：
$expectedFormat

注意：
1. 直接返回JSON，不要包含其他格式
2. 确保数据格式正确
3. 根据你的角色身份和当前游戏情境做出决策

${_buildGameContext(player, state)}
''';

    final response = await _service.generateResponse(
      systemPrompt: '你是狼人杀游戏中的角色，请根据提示生成JSON格式的决策结果。',
      userPrompt: fullPrompt,
      context: {},
    );
    
    if (response.isValid) {
      return await _parseJsonWithCleaner(response.content);
    }
    
    return {};
  }
  
  String _buildGameContext(GamePlayer player, GameState state) {
    final alivePlayers = state.alivePlayers.map((p) => p.name).join(', ');
    final deadPlayers = state.deadPlayers.map((p) => p.name).join(', ');

    return '''
游戏状态：
- 第${state.dayNumber}天
- 当前阶段：${state.currentPhase.displayName}
- 存活玩家：${alivePlayers.isNotEmpty ? alivePlayers : '无'}
- 死亡玩家：${deadPlayers.isNotEmpty ? deadPlayers : '无'}
- 你的状态：${player.isAlive ? '存活' : '死亡'}
- 你的角色：${player.role.name}
''';
  }
  
  Future<Map<String, dynamic>> _parseJsonWithCleaner(String content) async {
    try {
      final cleanedContent = JsonCleaner.extractJson(content);
      return jsonDecode(cleanedContent);
    } catch (e) {
      final partialJson = JsonCleaner.extractPartialJson(content);
      return partialJson ?? {};
    }
  }
}

// 人类玩家驱动器
class HumanPlayerDriver implements PlayerDriver {
  @override
  Future<Map<String, dynamic>> generateSkillResponse({
    required GamePlayer player,
    required GameState state,
    required String skillPrompt,
    required String expectedFormat,
  }) async {
    // 通过UI等待人类输入
    return await _waitForHumanInput(skillPrompt, expectedFormat);
  }
  
  Future<Map<String, dynamic>> _waitForHumanInput(String prompt, String format) async {
    // 实现人类输入逻辑
    throw UnimplementedError('人类玩家输入需要UI层实现');
  }
}
```

#### 设计优势
- **配置独立**: 每个玩家有自己的Driver，配置完全独立
- **职责明确**: 每个Driver只负责驱动一个玩家
- **扩展性好**: 新增玩家类型只需实现对应的Driver

## 4. 目录结构调整

### 4.1 保留的核心模块

```
lib/core/
├── domain/                    # 领域模型（重构）
│   ├── entities/              # 实体
│   │   ├── game_player.dart   # 游戏玩家抽象基类
│   │   ├── ai_player.dart     # AI玩家实现
│   │   ├── human_player.dart  # 人类玩家实现
│   │   └── game_role.dart     # 游戏角色实体（包含技能列表）
│   ├── skills/                # 新增：技能系统
│   │   ├── game_skill.dart    # 技能抽象基类
│   │   ├── night_skills.dart  # 夜晚技能实现
│   │   ├── day_skills.dart    # 白天技能实现
│   │   └── vote_skills.dart   # 投票技能实现
│   ├── value_objects/         # 值对象（保留）
│   └── enums/                 # 枚举（保留，移除PlayerType）
├── engine/                    # 游戏引擎（大幅简化）
│   ├── game_engine.dart       # 重构后的游戏引擎
│   ├── game_observer.dart     # 观察者接口（保留）
│   ├── processors/            # 阶段处理器
│   │   ├── phase_processor.dart     # 阶段处理器基类
│   │   ├── night_phase_processor.dart
│   │   └── day_phase_processor.dart
│   └── utils/                 # 工具类
│       └── game_random.dart   # 随机数生成工具
├── events/                    # 事件系统（保留）
├── scenarios/                 # 游戏场景（简化）
│   ├── game_scenario.dart     # 简化后的场景接口
│   ├── scenario_9_players.dart
│   └── scenario_12_players.dart
├── state/                     # 状态管理（简化）
│   └── game_state.dart        # 核心游戏状态
└── rules/                     # 规则引擎（保留）
```

### 4.2 删除的模块

```
lib/core/
├── engine/
│   └── game_parameters.dart   # 删除 - 职责混乱
├── scenarios/
│   └── scenario_registry.dart  # 删除 - 外部管理
├── services/                  # 删除 - 外部服务
│   ├── action_resolver_service.dart
│   ├── event_filter_service.dart
│   └── player_order_service.dart
└── state/                     # 删除 - 被技能系统取代
    ├── night_action_state.dart
    └── voting_state.dart
```

## 5. 迁移指南

### 5.1 游戏引擎使用变化

**重构前**:
```dart
// 1. 初始化复杂的参数系统
final parameters = FlutterGameParameters.instance;
await parameters.initialize();
parameters.setCurrentScenario('9_players');

// 2. 创建游戏引擎
final engine = GameEngine(parameters: parameters);

// 3. 外部创建玩家
final players = createPlayersForScenario(parameters.scenario!, parameters.config);
engine.setPlayers(players);
```

**重构后**:
```dart
// 1. 组装游戏
final engine = await GameAssembler.assembleGame(
  scenarioId: '9_players',
  observer: StreamGameObserver(),
);

// 2. 启动游戏
await engine.initializeGame();

// 3. 执行游戏步骤
while (!engine.isGameEnded) {
  await engine.executeGameStep();
}
```

### 5.2 配置系统变化

**重构前**:
```dart
// 复杂的配置系统
class AppConfig {
  final LLMConfig defaultLLM;
  final Map<int, LLMConfig> playerModels;
  final LoggingConfig logging;
  final TimeoutConfig timeouts;
  // ... 大量配置
}
```

**重构后**:
```dart
// 简化的配置系统
class GameConfig {
  final List<PlayerIntelligence> playerIntelligences;
  final int maxRetries;
}
```

### 5.3 场景系统变化

**重构前**:
```dart
// 场景需要注册和管理
final registry = ScenarioRegistry();
registry.initialize();
final scenario = registry.getScenario('9_players');
```

**重构后**:
```dart
// 直接使用场景
final scenario = Scenario9Players();
```

## 6. 优势总结

### 6.1 职责清晰
- **GameEngine**: 纯粹的游戏逻辑执行器
- **GameConfig**: 最小化的游戏配置
- **GameScenario**: 游戏规则定义
- **Player**: 游戏参与者抽象

### 6.2 易于测试
```dart
// 可以轻松测试任何游戏场景
test('9人局游戏测试', () async {
  final playerIntelligences = [
    PlayerIntelligence(
      baseUrl: 'https://api.openai.com/v1',
      apiKey: 'test-key',
      modelId: 'gpt-4',
    ),
    PlayerIntelligence(
      baseUrl: 'https://api.anthropic.com/v1',
      apiKey: 'test-key',
      modelId: 'claude-3',
    ),
    // ... 其他玩家配置
  ];
  
  final engine = GameEngine(
    config: GameConfig(
      playerIntelligences: playerIntelligences,
      maxRetries: 3,
    ),
    scenario: Scenario9Players(),
    players: createTestGamePlayers(),
    observer: TestGameObserver(),
  );
  
  await engine.initializeGame();
  
  // 测试游戏逻辑
  await engine.executeGameStep();
  expect(engine.currentState!.currentPhase, GamePhase.night);
  
  // 验证内部状态
  expect(engine.currentState!.players.length, 9);
  expect(engine.currentState!.dayNumber, 1);
  
  // 验证配置
  expect(engine.config.playerIntelligences.length, greaterThan(0));
  expect(engine.config.maxRetries, 3);
  
  // 验证玩家都有自己的驱动器
  expect(engine.players[0].driver, isA<AIPlayerDriver>());
  expect(engine.players[1].driver, isA<AIPlayerDriver>());
});
```

### 6.3 易于扩展
- 新增游戏场景：直接实现 `GameScenario` 接口
- 新增玩家类型：直接继承 `GamePlayer` 类
- 新增游戏规则：在 `GameScenario` 中定义
- 新增AI模型：在 `GameConfig.playerIntelligences` 中添加配置

### 6.4 完全解耦
- 游戏引擎不关心外部系统
- 可以在Console、Flutter、Web等任何环境中运行
- 通过Observer模式与外界交互

### 6.5 架构简洁性
- **GameEngine** 只需要4个外部输入，内部结构极其简单
- **技能系统** 统一了所有游戏行为，消除概念碎片化
- **每个GamePlayer有自己的PlayerDriver**，配置完全独立
- **移除了所有过度设计的组件**：StreamController、各种Manager、复杂的状态类
- **游戏流程通过简单的switch语句选择处理器**，避免不必要的Map管理

## 7. 实施计划

### 阶段1：核心接口重构
1. 定义新的 `GameConfig` 类
2. 定义 `PlayerIntelligence` 类
3. 简化 `GameScenario` 接口
4. 重构 `GamePlayer` 为抽象基类，创建 `AIPlayer` 和 `HumanPlayer` 实现
5. 重命名 `Role` 为 `GameRole`，整合Prompt系统和技能系统
6. 创建新的 `GameEngine` 实现
7. 设计技能系统架构（GameSkill、SkillResult、SkillEffect等）

### 阶段2：删除旧架构
1. 删除 `GameParameters` 接口
2. 删除 `ScenarioRegistry` 类
3. 删除 `PlayerType` 枚举
4. 删除不必要的服务类
5. 删除Action相关类（被技能系统取代）
6. 重命名 `LLMService` 为 `PlayerDriver`
7. 重命名 `LLMModel` 为 `PlayerIntelligence`
8. 整合散落外部的Prompt到GameRole中

### 阶段4：外部适配器重构
1. 创建 `GameAssembler` 类
2. 重构Flutter适配器
3. 重构Console适配器

### 阶段5：测试和验证
1. 编写单元测试
2. 集成测试验证
3. 性能测试验证

## 8. 风险评估

### 8.1 兼容性风险
- **影响**: 现有的游戏服务需要适配
- **缓解**: 提供适配器层，逐步迁移

### 8.2 功能风险
- **影响**: 可能丢失某些功能
- **缓解**: 仔细分析现有功能，确保必要功能不丢失

### 8.3 性能风险
- **影响**: 重构可能影响性能
- **缓解**: 性能测试对比，确保性能不下降

## 9. 总结

### 9.1 核心设计理念

本次重构实现了真正的**游戏引擎自洽运行**：

1. **外部输入**: 游戏引擎只需要4个外部输入
   - `GameConfig` - AI模型配置（包含玩家智能和重试次数）
   - `GameScenario` - 游戏规则定义
   - `List<GamePlayer>` - 游戏参与者
   - `GameObserver` - 外界交互接口

2. **内部自洽**: 游戏引擎内部结构极其简洁
   - 核心状态：GameState和GameStatus
   - 阶段处理器：2个专门的处理器（夜晚、白天）
   - 工具类：GameRandom随机数生成
   - 技能系统：统一所有游戏行为
   - 每个玩家有自己的PlayerDriver

3. **解耦交互**: 通过Observer模式与外界完全分离
   - 游戏引擎只负责触发事件
   - 不关心谁接收事件、如何处理

### 9.2 架构优势

- **职责明确**: 游戏引擎专注于游戏逻辑执行
- **状态自洽**: 内部管理所有必要状态和工具
- **易于测试**: 可以独立测试任何游戏场景
- **易于扩展**: 新增功能不影响现有代码
- **完全解耦**: 可以在任何环境中运行

### 9.3 关键变化

1. **简化接口**: 从复杂的GameParameters到4个简单参数
2. **内部管理**: 游戏引擎内部创建所有必要组件
3. **状态封装**: 专门的管理器处理不同类型的状态
4. **流程控制**: 通过处理器模式实现游戏流程控制
5. **LLM集成**: 直接使用用户现有的OpenAIService，避免不必要的抽象
6. **多态玩家**: 通过继承关系代替枚举，实现真正的面向对象设计
7. **技能系统**: 统一所有游戏行为为技能，消除概念碎片化

这次重构将游戏引擎从一个"万能系统"转变为一个**真正的游戏逻辑执行器**，实现了获得必要信息后能够自洽运转的目标。通过直接使用用户现有的OpenAIService实现，避免了不必要的抽象层，保持了代码的简洁性和可维护性。新的多态玩家设计、统一的技能系统、简化的PlayerDriver架构和移除过度设计的SkillContext/SkillEffect让系统更加灵活和可扩展。