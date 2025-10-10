import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:werewolf_arena/core/engine/game_state.dart';
import 'package:werewolf_arena/core/player/player.dart';
import 'logger.dart';

/// Player-specific logger for debugging event visibility
class PlayerLogger {
  static PlayerLogger? _instance;

  final String _playerLogsDirName = 'player_logs';
  final Map<String, IOSink> _playerSinks = {};
  String? _appDocDir;

  PlayerLogger._internal();

  /// Get singleton instance
  static PlayerLogger get instance {
    _instance ??= PlayerLogger._internal();
    return _instance!;
  }

  /// Get the player logs directory path
  Future<String> _getPlayerLogsDir() async {
    // 在 Flutter 环境下，使用应用文档目录
    if (!kIsWeb &&
        (Platform.isAndroid ||
            Platform.isIOS ||
            Platform.isMacOS ||
            Platform.isWindows ||
            Platform.isLinux)) {
      _appDocDir ??= (await getApplicationDocumentsDirectory()).path;
      return path.join(_appDocDir!, _playerLogsDirName);
    }

    // 在其他环境下，使用相对路径
    final gameSessionDir = LoggerUtil.instance.gameSessionDir;
    if (gameSessionDir != null) {
      return gameSessionDir;
    } else {
      return _playerLogsDirName;
    }
  }

  /// Initialize player logger
  Future<void> initialize() async {
    try {
      final logDirPath = await _getPlayerLogsDir();
      final logDir = Directory(logDirPath);
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to create player logs directory: $e');
      }
    }
  }

  /// Update player's visible events log before their action
  void updatePlayerEvents(Player player, GameState state) {
    // 在 Flutter 移动端禁用文件日志，避免权限问题
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return; // 静默跳过，不记录日志
    }

    try {
      // Close existing sink if it exists
      if (_playerSinks.containsKey(player.name)) {
        _playerSinks[player.name]!.close();
        _playerSinks.remove(player.name);
      }

      // 异步创建日志（不阻塞游戏流程）
      _createPlayerLogAsync(player, state);
    } catch (e) {
      // 静默处理错误
      if (kDebugMode) {
        print('Failed to update events log for player ${player.name}: $e');
      }
    }
  }

  /// 异步创建玩家日志（不阻塞主流程）
  void _createPlayerLogAsync(Player player, GameState state) {
    _getPlayerLogsDir()
        .then((logDirPath) {
          final fileName = 'player_${player.name}.log';
          final fullPath = path.join(logDirPath, fileName);
          final logFile = File(fullPath);
          final sink = logFile.openWrite(mode: FileMode.write);

          // Write all visible events
          final visibleEvents = state.getEventsForPlayer(player);
          for (int i = 0; i < visibleEvents.length; i++) {
            final event = visibleEvents[i];
            sink.writeln('⏺ ${event.toJson()}\n');
          }

          sink.flush().then((_) => sink.close());
        })
        .catchError((e) {
          if (kDebugMode) {
            print('Failed to create log for player ${player.name}: $e');
          }
        });
  }

  /// Update events for all players (useful for debugging)
  void updateAllPlayersEvents(GameState state) {
    for (final player in state.players) {
      updatePlayerEvents(player, state);
    }
  }

  /// Clean up all player log files
  Future<void> clearAllLogs() async {
    try {
      final logDirPath = await _getPlayerLogsDir();
      final logDir = Directory(logDirPath);
      if (logDir.existsSync()) {
        for (final file in logDir.listSync()) {
          if (file is File &&
              file.path.endsWith('.log') &&
              path.basename(file.path).startsWith('player_')) {
            file.deleteSync();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to clear player logs: $e');
      }
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    try {
      for (final sink in _playerSinks.values) {
        await sink.close();
      }
      _playerSinks.clear();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to dispose PlayerLogger: $e');
      }
    }
    _instance = null;
  }
}
