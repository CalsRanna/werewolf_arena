import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:werewolf_arena/engine/game_state.dart';
import 'package:werewolf_arena/engine/domain/entities/game_player.dart';
import '../../util/logger_util.dart';

/// 玩家专用日志器 - 用于记录玩家可见事件，便于调试
class PlayerLogger {
  static PlayerLogger? _instance;

  PlayerLogger._internal();

  /// 获取单例实例
  static PlayerLogger get instance {
    _instance ??= PlayerLogger._internal();
    return _instance!;
  }

  /// 记录玩家的可见事件到单独的文件
  ///
  /// [player] 玩家对象
  /// [state] 游戏状态
  /// [logDir] 日志目录，默认为 'logs/players'
  Future<void> logPlayerEvents(
    GamePlayer player,
    GameState state, {
    String logDir = 'logs/players',
  }) async {
    try {
      // 创建玩家日志目录
      final playerLogsDir = Directory(logDir);
      if (!await playerLogsDir.exists()) {
        await playerLogsDir.create(recursive: true);
      }

      // 创建玩家专用日志文件
      final fileName = 'player_${player.name}_events.log';
      final filePath = path.join(logDir, fileName);
      final logFile = File(filePath);

      // 获取玩家可见的事件
      final visibleEvents = state.getEventsForGamePlayer(player);

      // 写入日志
      final sink = logFile.openWrite(mode: FileMode.write);

      sink.writeln('=== 玩家 ${player.name} 的可见事件日志 ===');
      sink.writeln('角色: ${player.role.name}');
      sink.writeln('游戏ID: ${state.gameId}');
      sink.writeln('当前天数: ${state.dayNumber}');
      sink.writeln('当前阶段: ${state.currentPhase.displayName}');
      sink.writeln('生成时间: ${DateTime.now()}');
      sink.writeln('======================================\\n');

      for (int i = 0; i < visibleEvents.length; i++) {
        final event = visibleEvents[i];
        sink.writeln('事件 ${i + 1}:');
        sink.writeln('  类型: ${event.type.name}');
        sink.writeln('  时间: ${event.timestamp}');
        sink.writeln('  发起者: ${event.initiator?.name ?? 'N/A'}');
        sink.writeln('  目标: ${event.target?.name ?? 'N/A'}');
        sink.writeln('  可见性: ${event.visibility.name}');
        sink.writeln('  JSON: ${event.toJson()}');
        sink.writeln('');
      }

      await sink.flush();
      await sink.close();

      // 使用主日志器记录操作
      LoggerUtil.instance.d('已为玩家 ${player.name} 生成事件日志: $filePath');
    } catch (e) {
      LoggerUtil.instance.e('为玩家 ${player.name} 生成事件日志失败', e);
    }
  }

  /// 为所有玩家记录可见事件日志
  Future<void> logAllPlayersEvents(GameState state) async {
    LoggerUtil.instance.i('开始为所有玩家生成事件日志...');

    for (final player in state.players) {
      await logPlayerEvents(player, state);
    }

    LoggerUtil.instance.i('所有玩家事件日志生成完成');
  }

  /// 清理玩家日志文件
  ///
  /// [logDir] 日志目录，默认为 'logs/players'
  /// [olderThanDays] 删除多少天前的日志文件，默认为7天
  Future<void> clearOldLogs({
    String logDir = 'logs/players',
    int olderThanDays = 7,
  }) async {
    try {
      final playerLogsDir = Directory(logDir);
      if (!await playerLogsDir.exists()) {
        return;
      }

      final cutoffTime = DateTime.now().subtract(Duration(days: olderThanDays));
      int deletedCount = 0;

      await for (final entity in playerLogsDir.list()) {
        if (entity is File &&
            entity.path.contains('player_') &&
            entity.path.endsWith('.log')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffTime)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }

      LoggerUtil.instance.i('清理完成，删除了 $deletedCount 个过期的玩家日志文件');
    } catch (e) {
      LoggerUtil.instance.e('清理玩家日志文件失败', e);
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    _instance = null;
  }
}
