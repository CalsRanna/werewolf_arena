import 'player.dart';
import '../../state/game_state.dart';

/// AI性格状态 - 为AI玩家添加记忆和性格特征
class AIPersonalityState {
  // 基础性格特征
  final PersonalityType personalityType;
  double aggressiveness;      // 激进程度 0-1
  double logicThinking;       // 逻辑思维 0-1
  double cooperativeness;     // 合作倾向 0-1
  double honesty;            // 诚实程度 0-1
  double expressiveness;     // 表现欲望 0-1

  // 动态状态变量
  final Map<String, double> trustLevels = {};      // 对其他玩家的信任度 (playerName -> trustLevel)
  final Map<String, List<String>> memory = {};     // 对其他玩家的记忆 (playerName -> memories)
  final List<String> personalBeliefs = [];         // 个人信念和猜测
  EmotionalState emotionalState = EmotionalState.neutral; // 当前情绪状态

  // 游戏历史
  final List<String> speechHistory = [];           // 发言历史
  final Map<String, int> votingPattern = {};       // 投票模式统计 (playerName -> voteCount)
  int consecutiveCorrectDecisions = 0;             // 连续正确决策次数
  int consecutiveMistakes = 0;                     // 连续失误次数

  AIPersonalityState({
    required this.personalityType,
    this.aggressiveness = 0.5,
    this.logicThinking = 0.5,
    this.cooperativeness = 0.5,
    this.honesty = 0.8,
    this.expressiveness = 0.5,
  });

  /// 初始化信任度
  void initializeTrustLevels(List<Player> allPlayers, String currentPlayerName) {
    for (final player in allPlayers) {
      if (player.name != currentPlayerName) {
        trustLevels[player.name] = 0.5; // 初始中等信任度
        memory[player.name] = [];
      }
    }
  }

  /// 更新对某玩家的信任度
  void updateTrustLevel(String playerName, double deltaChange, String reason) {
    final currentValue = trustLevels[playerName] ?? 0.5;
    trustLevels[playerName] = (currentValue + deltaChange).clamp(0.0, 1.0);

    // 记录信任度变化的原因
    final playerMemory = memory[playerName] ?? <String>[];
    playerMemory.add(reason);
    if (playerMemory.length > 10) {
      playerMemory.removeAt(0); // 只保留最近10条记忆
    }
    memory[playerName] = playerMemory;
  }

  /// 根据性格类型调整决策权重
  double getDecisionWeight(String decisionType) {
    switch (personalityType) {
      case PersonalityType.aggressive:
        if (decisionType == 'attack') return 1.5;
        if (decisionType == 'defend') return 0.7;
        break;
      case PersonalityType.logical:
        if (decisionType == 'analyze') return 1.4;
        if (decisionType == 'intuitive') return 0.6;
        break;
      case PersonalityType.follower:
        if (decisionType == 'follow') return 1.6;
        if (decisionType == 'lead') return 0.5;
        break;
      case PersonalityType.emotional:
        if (decisionType == 'emotional') return 1.3;
        if (decisionType == 'rational') return 0.8;
        break;
    }
    return 1.0;
  }

  /// 生成基于当前状态的性格描述
  String generatePersonalityDescription() {
    String baseDesc = '';
    switch (personalityType) {
      case PersonalityType.aggressive:
        baseDesc = '激进型玩家，喜欢带头冲锋';
        break;
      case PersonalityType.logical:
        baseDesc = '逻辑流玩家，注重分析推理';
        break;
      case PersonalityType.follower:
        baseDesc = '跟随型玩家，倾向于相信强神';
        break;
      case PersonalityType.emotional:
        baseDesc = '情绪型玩家，容易激动或紧张';
        break;
    }

    String emotionalDesc = '';
    switch (emotionalState) {
      case EmotionalState.neutral:
        emotionalDesc = '情绪平稳';
        break;
      case EmotionalState.suspicious:
        emotionalDesc = '怀疑一切';
        break;
      case EmotionalState.confident:
        emotionalDesc = '信心十足';
        break;
      case EmotionalState.nervous:
        emotionalDesc = '紧张不安';
        break;
      case EmotionalState.angry:
        emotionalDesc = '愤怒激动';
        break;
    }

    return '$baseDesc，当前$emotionalDesc';
  }

  /// 分析发言并更新情绪和信任度
  void analyzeSpeech(String speakerName, String speech, bool isLogical) {
    // 如果发言逻辑清晰，提高信任度
    if (isLogical) {
      updateTrustLevel(speakerName, 0.1, '发言逻辑清晰');
    } else {
      updateTrustLevel(speakerName, -0.15, '发言有问题');
    }

    // 根据连续正确/错误决策调整情绪
    if (consecutiveCorrectDecisions >= 2) {
      emotionalState = EmotionalState.confident;
    } else if (consecutiveMistakes >= 2) {
      emotionalState = EmotionalState.nervous;
    }
  }

  /// 记录投票并分析模式
  void recordVote(String targetName) {
    votingPattern[targetName] = (votingPattern[targetName] ?? 0) + 1;
  }

  /// 检查投票一致性
  bool isConsistentVoter() {
    if (votingPattern.isEmpty) return true;

    // 如果经常投票给不同的人，说明不够一致
    return votingPattern.length <= 2;
  }

  /// 生成个人猜测和信念
  void updatePersonalBeliefs(GameState state) {
    personalBeliefs.clear();

    // 根据信任度生成猜测
    trustLevels.forEach((playerName, trustLevel) {
      if (trustLevel < 0.3) {
        personalBeliefs.add('$playerName可能是狼人');
      } else if (trustLevel > 0.8) {
        personalBeliefs.add('$playerName很可能是好人');
      }
    });

    // 根据性格类型调整猜测
    if (personalityType == PersonalityType.aggressive && consecutiveMistakes == 0) {
      personalBeliefs.add('我觉得自己找到狼人了');
    }
  }

  /// 重置连续计数
  void resetStreakCounters() {
    consecutiveCorrectDecisions = 0;
    consecutiveMistakes = 0;
  }

  /// 记录正确决策
  void recordCorrectDecision() {
    consecutiveCorrectDecisions++;
    consecutiveMistakes = 0;
    if (consecutiveCorrectDecisions > 3) {
      emotionalState = EmotionalState.confident;
    }
  }

  /// 记录失误
  void recordMistake() {
    consecutiveMistakes++;
    consecutiveCorrectDecisions = 0;
    if (consecutiveMistakes > 2) {
      emotionalState = EmotionalState.nervous;
    }
  }
}

/// 性格类型枚举
enum PersonalityType {
  aggressive,    // 激进型：喜欢带头，容易冲动
  logical,       // 逻辑型：注重推理，相对理性
  follower,      // 跟随型：容易相信权威，缺乏主见
  emotional,     // 情绪型：情绪波动大，容易被影响
}

/// 情绪状态枚举
enum EmotionalState {
  neutral,       // 中性
  suspicious,    // 怀疑
  confident,     // 自信
  nervous,       // 紧张
  angry,         // 愤怒
}

/// 工具类：创建不同类型的AI性格
class AIPersonalityFactory {
  /// 创建激进型AI
  static AIPersonalityState createAggressive() {
    return AIPersonalityState(
      personalityType: PersonalityType.aggressive,
      aggressiveness: 0.8,
      logicThinking: 0.4,
      cooperativeness: 0.3,
      honesty: 0.6,
      expressiveness: 0.9,
    );
  }

  /// 创建逻辑型AI
  static AIPersonalityState createLogical() {
    return AIPersonalityState(
      personalityType: PersonalityType.logical,
      aggressiveness: 0.3,
      logicThinking: 0.9,
      cooperativeness: 0.6,
      honesty: 0.9,
      expressiveness: 0.4,
    );
  }

  /// 创建跟随型AI
  static AIPersonalityState createFollower() {
    return AIPersonalityState(
      personalityType: PersonalityType.follower,
      aggressiveness: 0.2,
      logicThinking: 0.5,
      cooperativeness: 0.9,
      honesty: 0.7,
      expressiveness: 0.5,
    );
  }

  /// 创建情绪型AI
  static AIPersonalityState createEmotional() {
    return AIPersonalityState(
      personalityType: PersonalityType.emotional,
      aggressiveness: 0.6,
      logicThinking: 0.3,
      cooperativeness: 0.5,
      honesty: 0.8,
      expressiveness: 0.9,
    );
  }

  /// 随机创建一种性格
  static AIPersonalityState createRandom() {
    final types = PersonalityType.values;
    final randomType = types[DateTime.now().millisecond % types.length];

    switch (randomType) {
      case PersonalityType.aggressive:
        return createAggressive();
      case PersonalityType.logical:
        return createLogical();
      case PersonalityType.follower:
        return createFollower();
      case PersonalityType.emotional:
        return createEmotional();
    }
  }
}