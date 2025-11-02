import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/reasoning/memory/relationship.dart';
import 'package:werewolf_arena/engine/reasoning/memory/social_network.dart';
import 'package:werewolf_arena/engine/reasoning/memory/working_memory.dart';
import 'package:werewolf_arena/engine/player/game_player.dart';

/// 社交分析器
///
/// 基于身份推理结果和策略计划更新社交关系网络
class SocialAnalyzer {
  /// 基于身份推理结果更新社交网络
  ///
  /// [currentNetwork] 当前的社交网络
  /// [identityEstimates] 身份推理结果
  /// [player] 当前玩家
  /// [state] 游戏状态
  static SocialNetwork updateFromIdentityInference({
    required SocialNetwork currentNetwork,
    required Map<String, IdentityEstimate> identityEstimates,
    required GamePlayer player,
    required GameState state,
  }) {
    final updatedRelationships = <String, Relationship>{};

    for (final entry in identityEstimates.entries) {
      final targetPlayerName = entry.key; // 这是playerName
      final estimate = entry.value;

      // 通过名称查找玩家
      final targetPlayer = state.players.firstWhere(
        (p) => p.name == targetPlayerName,
        orElse: () => state.players.first,
      );

      // 获取当前关系（使用playerId）
      final currentRelation = currentNetwork.getRelationship(targetPlayer.id);

      if (currentRelation == null) continue;

      // 基于推理结果计算新的信任度和怀疑度
      final newRelation = _calculateRelationshipFromEstimate(
        currentRelation: currentRelation,
        estimate: estimate,
        player: player,
        targetPlayer: targetPlayer,
        state: state,
      );

      updatedRelationships[targetPlayer.id] = newRelation;
    }

    if (updatedRelationships.isEmpty) {
      return currentNetwork;
    }

    return currentNetwork.updateMultipleRelationships(updatedRelationships);
  }

  /// 基于策略计划更新社交网络
  ///
  /// [currentNetwork] 当前的社交网络
  /// [strategy] 策略计划
  /// [state] 游戏状态
  static SocialNetwork updateFromStrategy({
    required SocialNetwork currentNetwork,
    required Map<String, dynamic> strategy,
    required GameState state,
  }) {
    final updatedRelationships = <String, Relationship>{};

    // 如果策略中有目标玩家，提升对该玩家的关注度
    final targetPlayerName = strategy['target'] as String?;
    if (targetPlayerName != null) {
      final targetPlayer = state.players.firstWhere(
        (p) => p.name == targetPlayerName,
        orElse: () => state.players.first,
      );

      final currentRelation = currentNetwork.getRelationship(targetPlayer.id);
      if (currentRelation != null) {
        // 增加关系强度（因为这是重点关注的玩家）
        final newStrength = (currentRelation.strength + 0.2).clamp(0.0, 1.0);
        final newRelation = currentRelation
            .update(strength: newStrength)
            .addEvidence('策略重点关注对象');

        updatedRelationships[targetPlayer.id] = newRelation;
      }
    }

    if (updatedRelationships.isEmpty) {
      return currentNetwork;
    }

    return currentNetwork.updateMultipleRelationships(updatedRelationships);
  }

  /// 分析社交模式并提供建议
  ///
  /// 返回针对当前社交网络的战术建议
  static List<String> analyzeSocialPatterns({
    required SocialNetwork network,
    required GamePlayer player,
    required GameState state,
  }) {
    final suggestions = <String>[];

    final allies = network.allies;
    final enemies = network.enemies;

    // 分析盟友情况
    if (allies.isEmpty) {
      suggestions.add('当前没有明确的盟友，需要建立信任关系');
    } else if (allies.length > 5) {
      suggestions.add('盟友过多可能导致站边不清晰，需要明确核心盟友');
    }

    // 分析敌人情况
    if (enemies.isEmpty && state.day > 1) {
      suggestions.add('尚未识别明确的敌人，需要加强身份推理');
    }

    // 分析强关系
    final strongRelations = network.getStrongRelationships();
    if (strongRelations.length < 2 && state.day > 2) {
      suggestions.add('关系网络不够清晰，需要更积极地建立或打击关系');
    }

    // 特殊角色建议
    if (player.role.id == 'werewolf') {
      // 狼人建议
      if (allies.length > enemies.length) {
        suggestions.add('作为狼人，可以考虑挑起盟友之间的矛盾');
      }
    } else if (player.role.id == 'seer') {
      // 预言家建议
      if (allies.isEmpty) {
        suggestions.add('作为预言家，需要报出金水建立信任关系');
      }
    }

    return suggestions;
  }

  /// 从身份估计计算关系
  static Relationship _calculateRelationshipFromEstimate({
    required Relationship currentRelation,
    required IdentityEstimate estimate,
    required GamePlayer player,
    required GamePlayer targetPlayer,
    required GameState state,
  }) {
    // 基于玩家的真实身份和推理结果计算信任度

    double newTrustLevel = currentRelation.trustLevel;
    double newSuspicionLevel = currentRelation.suspicionLevel;
    RelationshipType newType = currentRelation.type;

    // 如果是狼人阵营
    if (player.role.id == 'werewolf') {
      // 推测对方是狼人 -> 可能是队友
      if (estimate.estimatedRole == 'werewolf') {
        if (state.werewolves.any((w) => w.id == targetPlayer.id)) {
          // 确实是队友
          newTrustLevel = 100;
          newSuspicionLevel = 0;
          newType = RelationshipType.ally;
        } else {
          // 推测错误，对方不是狼人
          newSuspicionLevel = estimate.confidence * 0.5;
        }
      } else {
        // 推测对方是好人
        newSuspicionLevel = 0;
        newTrustLevel = estimate.confidence * 0.3; // 轻度信任（好忽悠）
      }
    } else {
      // 好人阵营
      if (estimate.estimatedRole == 'werewolf') {
        // 推测对方是狼人
        newTrustLevel = -estimate.confidence.toDouble();
        newSuspicionLevel = estimate.confidence.toDouble();
        newType = RelationshipType.enemy;
      } else if (estimate.estimatedRole == 'seer' ||
          estimate.estimatedRole == 'witch' ||
          estimate.estimatedRole == 'hunter') {
        // 推测对方是神职
        newTrustLevel = estimate.confidence * 0.7;
        newSuspicionLevel = (100 - estimate.confidence) * 0.3;
        newType = RelationshipType.ally;
      } else {
        // 推测对方是村民
        newTrustLevel = estimate.confidence * 0.5;
        newSuspicionLevel = 0;
        newType = RelationshipType.neutral;
      }
    }

    // 计算关系强度（基于置信度）
    final newStrength = (estimate.confidence / 100).clamp(0.0, 1.0);

    return currentRelation
        .update(
          trustLevel: newTrustLevel,
          suspicionLevel: newSuspicionLevel,
          type: newType,
          strength: newStrength,
        )
        .addEvidence(estimate.reasoning);
  }

  /// 获取社交网络摘要
  static String getSummary(SocialNetwork network, GameState state) {
    final allies = network.allies;
    final enemies = network.enemies;

    if (allies.isEmpty && enemies.isEmpty) {
      return '关系网络尚未建立';
    }

    final buffer = StringBuffer();

    if (allies.isNotEmpty) {
      final allyNames = allies
          .take(3)
          .map((id) {
            final player = state.players.firstWhere(
              (p) => p.id == id,
              orElse: () => state.players.first,
            );
            return player.name;
          })
          .join(', ');
      buffer.write('盟友: $allyNames');
    }

    if (enemies.isNotEmpty) {
      if (allies.isNotEmpty) buffer.write('; ');
      final enemyNames = enemies
          .take(3)
          .map((id) {
            final player = state.players.firstWhere(
              (p) => p.id == id,
              orElse: () => state.players.first,
            );
            return player.name;
          })
          .join(', ');
      buffer.write('敌人: $enemyNames');
    }

    return buffer.toString();
  }
}
