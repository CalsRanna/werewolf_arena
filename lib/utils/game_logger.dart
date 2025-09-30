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

  // 游戏日志相关
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

        // 不要写入游戏日志文件（避免重复）
      });
    } catch (e) {
      print('Failed to setup file logging: $e');
    }
  }

  /// 开始新游戏，创建游戏日志文件
  void startNewGame(String gameId) {
    try {
      // 关闭之前的游戏日志
      _gameLogSink?.close();

      // 确保logs目录存在
      final logDir = Directory(_logDir);
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }

      // 创建游戏日志文件名
      final timestamp = _fileNameFormat.format(DateTime.now());
      final fileName = 'game_${gameId}_$timestamp.log';
      _currentGameLogPath = path.join(_logDir, fileName);

      // 创建游戏日志文件
      final gameLogFile = File(_currentGameLogPath!);
      _gameLogSink = gameLogFile.openWrite();

      // 写入游戏开始标记
      final startMessage = '''
==========================================
🎮 狼人杀游戏日志
游戏ID: $gameId
开始时间: ${_dateFormat.format(DateTime.now())}
==========================================
''';

      _gameLogSink!.writeln(startMessage);
      info('游戏日志已创建：$fileName');
    } catch (e) {
      error('创建游戏日志文件失败: $e');
    }
  }

  /// 结束当前游戏
  void endCurrentGame() {
    try {
      if (_gameLogSink != null) {
        final endMessage = '''
==========================================
📊 游戏结束
结束时间: ${_dateFormat.format(DateTime.now())}
日志文件: $_currentGameLogPath
==========================================
''';

        _gameLogSink!.writeln(endMessage);
        _gameLogSink!.close();
        _gameLogSink = null;

        info('游戏日志已结束并保存');
      }
    } catch (e) {
      error('结束游戏日志失败: $e');
    }
  }

  /// 记录阶段切换到游戏日志
  void logGamePhase(String phase, String description) {
    final phaseMessage = '''
------------------------------------------
📋 阶段: $phase
⏰ 时间: ${_dateFormat.format(DateTime.now())}
📝 描述: $description
------------------------------------------
''';

    _gameLogSink?.writeln(phaseMessage);
  }

  /// 记录玩家发言到游戏日志
  void logPlayerSpeech(
      String playerName, String roleName, String message, String phase) {
    final speechMessage = '''
💬 [$phase] $playerName($roleName):
   「$message」
''';

    _gameLogSink?.writeln(speechMessage);
  }

  /// 记录游戏事件到游戏日志
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
    logGameEvent('游戏开始，玩家数量：$playerCount');
  }

  void gameEnd(String gameId, String winner, int duration) {
    logGameEvent('游戏结束，获胜者：$winner，持续时间：$duration毫秒');
    endCurrentGame();
  }

  void playerAction(String playerId, String action, {String? target}) {
    // 简化：不记录普通的玩家行动到游戏日志
  }

  void phaseChange(String phase, int dayNumber) {
    logGamePhase(phase, '第 $dayNumber 天');
  }

  void playerDeath(String playerId, String cause) {
    logGameEvent('$playerId 死亡：$cause');
  }

  void skillUsed(String playerId, String skill, {String? target}) {
    logGameEvent('$playerId 使用技能：$skill${target != null ? ' 对 $target' : ''}');
  }

  void llmCall(String model, int tokens, int duration) {
    debug('LLM调用完成：$model | 令牌数：$tokens | 耗时：$duration毫秒');
  }

  void llmError(String error, {int retryCount = 0}) {
    warning('LLM错误（尝试次数 $retryCount）：$error');
  }

  void configLoaded(String configPath) {
    info('配置文件已加载：$configPath');
  }

  void stats(String stats) {
    info('游戏统计：$stats');
  }

  /// 销毁logger，关闭所有文件流
  void dispose() {
    try {
      endCurrentGame();
      info('GameLogger已销毁');
    } catch (e) {
      error('销毁GameLogger失败: $e');
    }
  }
}
