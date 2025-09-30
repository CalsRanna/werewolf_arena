import 'package:logging/logging.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'config_loader.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class GameLogger {
  static final Logger _logger = Logger('werewolf_arena');
  static GameLogger? _instance;

  final LoggingConfig _config;
  final String _logDir;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  final DateFormat _fileNameFormat = DateFormat('yyyy-MM-dd_HH-mm-ss');

  // Game log related
  IOSink? _gameLogSink;
  String? _currentGameLogPath;

  GameLogger._internal(this._config) : _logDir = 'logs' {
    _setupLogger();
  }

  factory GameLogger(LoggingConfig config) {
    _instance ??= GameLogger._internal(config);
    return _instance!;
  }

  void _setupLogger() {
    Logger.root.level = _getLogLevel(_config.level);

    if (_config.enableConsole) {
      Logger.root.onRecord.listen((record) {
        print(_formatRecord(record));
      });
    }

    if (_config.enableFile) {
      _setupFileLogging();
    }
  }

  void _setupFileLogging() {
    try {
      final logDir = Directory(_logDir);
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }

      final logFile = File(_config.logFilePath);
      final sink = logFile.openWrite(mode: FileMode.append);

      Logger.root.onRecord.listen((record) {
        final formattedRecord = _formatRecord(record);
        sink.writeln(formattedRecord);

        // Don't write to game log file (avoid duplication)
      });
    } catch (e) {
      print('Failed to setup file logging: $e');
    }
  }

  /// Start new game, create game log file
  void startNewGame(String gameId) {
    try {
      // Close previous game log
      _gameLogSink?.close();

      // Ensure logs directory exists
      final logDir = Directory(_logDir);
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }

      // Create game log file name
      final timestamp = _fileNameFormat.format(DateTime.now());
      final fileName = 'game_${gameId}_$timestamp.log';
      _currentGameLogPath = path.join(_logDir, fileName);

      // Create game log file
      final gameLogFile = File(_currentGameLogPath!);
      _gameLogSink = gameLogFile.openWrite();

      // Write game start marker
      final startMessage = '''
==========================================
🎮 Werewolf Game Log
Game ID: $gameId
Start Time: ${_dateFormat.format(DateTime.now())}
==========================================
''';

      _gameLogSink!.writeln(startMessage);
      info('Game log created: $fileName');
    } catch (e) {
      error('Failed to create game log file: $e');
    }
  }

  /// End current game
  void endCurrentGame() {
    try {
      if (_gameLogSink != null) {
        final endMessage = '''
==========================================
📊 Game Ended
End Time: ${_dateFormat.format(DateTime.now())}
Log File: $_currentGameLogPath
==========================================
''';

        _gameLogSink!.writeln(endMessage);
        _gameLogSink!.close();
        _gameLogSink = null;

        info('Game log ended and saved');
      }
    } catch (e) {
      error('Failed to end game log: $e');
    }
  }

  /// Record phase change to game log
  void logGamePhase(String phase, String description) {
    final phaseMessage = '''
------------------------------------------
📋 Phase: $phase
⏰ Time: ${_dateFormat.format(DateTime.now())}
📝 Description: $description
------------------------------------------
''';

    _gameLogSink?.writeln(phaseMessage);
  }

  /// Record player speech to game log
  void logPlayerSpeech(
      String playerName, String roleName, String message, String phase) {
    final speechMessage = '''
💬 [$phase] $playerName($roleName):
   「$message」
''';

    _gameLogSink?.writeln(speechMessage);
  }

  /// Record game event to game log
  void logGameEvent(String event, {Map<String, dynamic>? details}) {
    final eventMessage = '''
🎯 $event${details != null ? ' - ${details.entries.map((e) => '${e.key}: ${e.value}').join(', ')}' : ''}
''';

    _gameLogSink?.writeln(eventMessage);
  }

  Level _getLogLevel(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return Level('DEBUG', 300);
      case 'info':
        return Level('INFO', 800);
      case 'warning':
        return Level('WARNING', 900);
      case 'error':
        return Level('ERROR', 1000);
      case 'severe':
        return Level.SEVERE;
      case 'shout':
        return Level.SHOUT;
      default:
        return Level.INFO;
    }
  }

  String _formatRecord(LogRecord record) {
    final timestamp = _dateFormat.format(record.time);
    final level = record.level.name.toUpperCase();
    final message = record.message;
    final error = record.error != null ? ' | Error: ${record.error}' : '';
    final stack =
        record.stackTrace != null ? ' | Stack: ${record.stackTrace}' : '';

    return '[$timestamp] [$level] $message$error$stack';
  }

  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.fine(message, error, stackTrace);
  }

  void info(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.info(message, error, stackTrace);
  }

  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.warning(message, error, stackTrace);
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.severe(message, error, stackTrace);
  }

  void gameStart(String gameId, int playerCount) {
    logGameEvent('Game started, player count: $playerCount');
  }

  void gameEnd(String gameId, String winner, int duration) {
    logGameEvent('Game ended, winner: $winner, duration: $duration milliseconds');
    endCurrentGame();
  }

  void playerAction(String playerId, String action, {String? target}) {
    // Simplified: do not record normal player actions to game log
  }

  void phaseChange(String phase, int dayNumber) {
    logGamePhase(phase, 'Day $dayNumber');
  }

  void playerDeath(String playerId, String cause) {
    logGameEvent('$playerId died: $cause');
  }

  void skillUsed(String playerId, String skill, {String? target}) {
    logGameEvent('$playerId used skill: $skill${target != null ? ' on $target' : ''}');
  }

  void llmCall(String model, int tokens, int duration) {
    debug('LLM call completed: $model | tokens: $tokens | duration: $duration ms');
  }

  void llmError(String error, {int retryCount = 0}) {
    warning('LLM error (attempt $retryCount): $error');
  }

  void configLoaded(String configPath) {
    info('Configuration file loaded: $configPath');
  }

  void stats(String stats) {
    info('Game statistics: $stats');
  }

  /// Dispose logger, close all file streams
  void dispose() {
    try {
      endCurrentGame();
      info('GameLogger disposed');
    } catch (e) {
      error('Failed to dispose GameLogger: $e');
    }
  }
}
