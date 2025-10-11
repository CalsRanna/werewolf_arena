import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/events/base/game_event.dart';
import 'package:werewolf_arena/core/events/player_events.dart';
import 'package:werewolf_arena/core/events/skill_events.dart';
import 'package:werewolf_arena/core/events/phase_events.dart';
import 'package:werewolf_arena/core/events/system_events.dart';
import 'package:werewolf_arena/core/domain/entities/player.dart';
import 'package:werewolf_arena/core/domain/entities/role.dart';
import 'package:werewolf_arena/core/domain/value_objects/speech_type.dart';
import 'package:werewolf_arena/core/domain/value_objects/game_event_type.dart';

/// 逻辑验证器 - 为AI玩家提供常识判断支持
class LogicValidator {
  /// 检测发言中的逻辑矛盾并返回标签
  static List<String> detectContradictions(
    String message,
    Player speaker,
    GameState state,
  ) {
    final tags = <String>[];

    // 1. 检测事实性矛盾
    tags.addAll(_detectFactualContradictions(message, speaker, state));

    // 2. 检测聊爆发言
    tags.addAll(_detectSuspiciousStatements(message, speaker.role));

    // 3. 检测逻辑不一致
    tags.addAll(_detectLogicalInconsistencies(message, speaker, state));

    return tags;
  }

  /// 检测事实性矛盾
  static List<String> _detectFactualContradictions(
    String message,
    Player speaker,
    GameState state,
  ) {
    final tags = <String>[];
    final lowerMessage = message.toLowerCase();

    // 检查是否提到了错误的死亡状态
    for (final player in state.players) {
      final playerName = player.name.toLowerCase();
      final isAlive = player.isAlive;

      // 如果有人说活人死了
      if (lowerMessage.contains('$playerName死了') ||
          lowerMessage.contains('$playerName挂了') ||
          lowerMessage.contains('$playerName出局')) {
        if (isAlive) {
          tags.add('⚠️事实错误：${player.name}明明活着，却说${player.name}死了');
        }
      }

      // 如果有人说死人活着
      if (lowerMessage.contains('$playerName活着') ||
          lowerMessage.contains('$playerName还在') ||
          lowerMessage.contains('$playerName没死')) {
        if (!isAlive) {
          tags.add('⚠️事实错误：${player.name}已经死亡，却说${player.name}活着');
        }
      }
    }

    // 检查平安夜相关矛盾
    final recentNightResults = state.eventHistory
        .whereType<NightResultEvent>()
        .where((e) => e.dayNumber == state.dayNumber - 1) // 昨晚
        .toList();

    if (recentNightResults.isNotEmpty) {
      final lastNight = recentNightResults.last;
      if (lastNight.isPeacefulNight) {
        // 平安夜后有人声称被刀
        if (lowerMessage.contains('我昨晚被刀') ||
            lowerMessage.contains('狼人来找我') ||
            lowerMessage.contains('守卫救了我')) {
          tags.add('⚠️平安夜矛盾：昨晚是平安夜，怎么可能被刀？');
        }
      }
    }

    return tags;
  }

  /// 检测聊爆发言
  static List<String> _detectSuspiciousStatements(
    String message,
    Role speakerRole,
  ) {
    final tags = <String>[];
    final lowerMessage = message.toLowerCase();

    // 预言家相关的聊爆检测
    if (speakerRole.roleId == 'seer') {
      if (lowerMessage.contains('随便验') ||
          lowerMessage.contains('凭感觉') ||
          lowerMessage.contains('中间挑') ||
          lowerMessage.contains('随便选') ||
          lowerMessage.contains('没什么理由')) {
        tags.add('🚨聊爆预警：预言家说"随便验人"，这是假预言家的典型特征！');
      }

      // 术语使用错误检测
      if (lowerMessage.contains('查杀是个金水') ||
          lowerMessage.contains('金水是狼人') ||
          lowerMessage.contains('查杀结果是好人')) {
        tags.add('🚨术语错误：预言家混淆了查杀和金水的概念，绝对不可能！');
      }
    }

    // 通用聊爆检测
    if (lowerMessage.contains('我是狼人') ||
        lowerMessage.contains('我们狼队') ||
        lowerMessage.contains('刀谁')) {
      tags.add('🚨身份暴露：直接暴露了狼人身份！');
    }

    return tags;
  }

  /// 检测逻辑不一致
  static List<String> _detectLogicalInconsistencies(
    String message,
    Player speaker,
    GameState state,
  ) {
    final tags = <String>[];
    final lowerMessage = message.toLowerCase();

    // 检查投票与发言的一致性
    final recentVotes = state.eventHistory
        .where((e) => e.type == GameEventType.voteCast)
        .where((e) => e.initiator?.name == speaker.name)
        .toList();

    if (recentVotes.isNotEmpty) {
      final lastVote = recentVotes.last;
      final votedTarget = lastVote.target;

      // 如果发言支持某人但投票给了另一个人
      if (votedTarget != null) {
        if (lowerMessage.contains('${votedTarget.name}是好人') ||
            lowerMessage.contains('${votedTarget.name}是神') ||
            lowerMessage.contains('我相信${votedTarget.name}')) {
          tags.add('⚠️行为矛盾：发言说${votedTarget.name}是好人，但投票给了${votedTarget.name}');
        }
      }
    }

    // 检查声称的身份与行为的不一致
    if (speaker.role.roleId == 'seer') {
      // 如果自称预言家但没有查验信息
      final investigations = state.eventHistory
          .whereType<SeerInvestigateEvent>()
          .where((e) => e.initiator?.name == speaker.name)
          .toList();

      if (investigations.isEmpty && state.dayNumber > 1) {
        if (lowerMessage.contains('我是预言家') || lowerMessage.contains('我查验了')) {
          tags.add('⚠️身份可疑：自称预言家但一直没有查验结果？');
        }
      }
    }

    return tags;
  }

  /// 生成带有标签的事件描述
  static String formatEventWithTags(GameEvent event, GameState state) {
    if (event is SpeakEvent) {
      final speakerName = event.speaker.name;
      final message = event.message;
      final tags = detectContradictions(message, event.speaker, state);
      final baseDescription = '$speakerName: $message';

      if (tags.isNotEmpty) {
        final tagString = tags.join(' ');
        return '$baseDescription\n$tagString';
      }
    }

    // 使用原有的格式化方法
    return _formatEventDefault(event);
  }

  /// 默认的事件格式化方法
  static String _formatEventDefault(GameEvent event) {
    switch (event.type) {
      case GameEventType.gameStart:
        return '游戏开始';

      case GameEventType.gameEnd:
        return '游戏结束';

      case GameEventType.phaseChange:
        if (event is PhaseChangeEvent) {
          return '${event.oldPhase.name}→${event.newPhase.name}';
        } else if (event is JudgeAnnouncementEvent) {
          return '📢 ${event.announcement}';
        }
        return '阶段转换';

      case GameEventType.playerDeath:
        if (event is DeadEvent) {
          return '${event.victim.name}死亡(${event.cause.name})';
        }
        return '玩家死亡';

      case GameEventType.skillUsed:
        final actor = event.initiator?.name ?? '?';
        if (event is WerewolfKillEvent) {
          return '$actor刀${event.target!.name}';
        } else if (event is GuardProtectEvent) {
          return '$actor守${event.target!.name}';
        } else if (event is SeerInvestigateEvent) {
          return '$actor验${event.target!.name}:${event.investigationResult}';
        } else if (event is WitchHealEvent) {
          return '$actor救${event.target!.name}(重要：该玩家存活)';
        } else if (event is WitchPoisonEvent) {
          return '$actor毒${event.target!.name}';
        } else if (event is HunterShootEvent) {
          return '$actor枪${event.target!.name}';
        }
        return '$actor使用技能';

      case GameEventType.skillResult:
        final actor = event.initiator?.name ?? '?';
        return '$actor技能结果';

      case GameEventType.voteCast:
        final voter = event.initiator?.name ?? '?';
        final target = event.target?.name ?? '?';
        return '$voter投$target';

      case GameEventType.playerAction:
        if (event is SpeakEvent) {
          final speaker = event.speaker.name;
          if (event.speechType == SpeechType.normal) {
            return '$speaker: ${event.message}';
          } else if (event.speechType == SpeechType.lastWords) {
            return '$speaker(遗言): ${event.message}';
          } else if (event.speechType == SpeechType.werewolfDiscussion) {
            return '$speaker(狼): ${event.message}';
          }
        } else if (event is SpeechOrderAnnouncementEvent) {
          final order = event.speakingOrder.map((p) => p.name).join('→');
          return '📣 发言顺序: $order (${event.direction})';
        }
        return '事件类型: ${event.type.name}';

      case GameEventType.dayBreak:
        if (event is NightResultEvent) {
          if (event.isPeacefulNight) {
            return '🌙 平安夜！无人死亡';
          } else {
            final deaths = event.deathEvents
                .map((e) => e.victim.name)
                .join(',');
            return '天亮:$deaths死亡';
          }
        }
        return '天亮';

      case GameEventType.nightFall:
        return '天黑';
    }
  }
}
