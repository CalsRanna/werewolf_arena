import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:werewolf_arena/core/state/game_state.dart';
import 'package:werewolf_arena/core/entities/player/player.dart';
import 'logger.dart';

/// Player-specific logger for debugging event visibility
class PlayerLogger {
  static PlayerLogger? _instance;

  final String _playerLogsDirName = 'player_logs';
  final Map<String, IOSink> _playerSinks = {};

  PlayerLogger._internal();

  /// Get singleton instance
  static PlayerLogger get instance {
    _instance ??= PlayerLogger._internal();
    return _instance!;
  }

  /// Get the player logs directory path
  String _getPlayerLogsDir() {
    final gameSessionDir = LoggerUtil.instance.gameSessionDir;
    if (gameSessionDir != null) {
      // Place player logs in the same game session directory
      return gameSessionDir;
    } else {
      // Fallback to standalone player_logs directory
      return _playerLogsDirName;
    }
  }

  /// Initialize player logger
  void initialize() {
    try {
      final logDir = Directory(_getPlayerLogsDir());
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
    } catch (e) {
      stdout.writeln('Failed to create player logs directory: $e');
    }
  }

  /// Get or create log sink for a player
  IOSink _getPlayerSink(String playerName) {
    if (!_playerSinks.containsKey(playerName)) {
      try {
        final fileName = 'player_$playerName.log';
        final fullPath = path.join(_getPlayerLogsDir(), fileName);
        final logFile = File(fullPath);
        _playerSinks[playerName] =
            logFile.openWrite(mode: FileMode.write); // Overwrite each time
      } catch (e) {
        stdout.writeln('Failed to create log file for player $playerName: $e');
        rethrow;
      }
    }
    return _playerSinks[playerName]!;
  }

  /// Update player's visible events log before their action
  void updatePlayerEvents(Player player, GameState state) {
    try {
      // Close existing sink if it exists
      if (_playerSinks.containsKey(player.name)) {
        _playerSinks[player.name]!.close();
        _playerSinks.remove(player.name);
      }

      // Create new sink with write mode (overwrites file)
      final sink = _getPlayerSink(player.name);

      // Write all visible events to completely overwrite the file
      final visibleEvents = state.getEventsForPlayer(player);

      // Write all visible events
      for (int i = 0; i < visibleEvents.length; i++) {
        final event = visibleEvents[i];
        sink.writeln('⏺ ${event.toJson()}\n');
      }

      // Flush immediately to ensure data is written
      sink.flush();
    } catch (e) {
      stdout.writeln(
          'Failed to update events log for player ${player.name}: $e');
    }
  }

  /// Update events for all players (useful for debugging)
  void updateAllPlayersEvents(GameState state) {
    for (final player in state.players) {
      updatePlayerEvents(player, state);
    }
  }

  /// Clean up all player log files
  void clearAllLogs() {
    try {
      final logDir = Directory(_getPlayerLogsDir());
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
      stdout.writeln('Failed to clear player logs: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    try {
      for (final sink in _playerSinks.values) {
        sink.close();
      }
      _playerSinks.clear();
    } catch (e) {
      stdout.writeln('Failed to dispose PlayerLogger: $e');
    }
    _instance = null;
  }
}
