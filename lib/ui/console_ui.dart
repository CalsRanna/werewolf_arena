import 'dart:async';
import 'dart:io';
import '../game/game_state.dart';
import '../game/game_action.dart';
import '../player/player.dart';
import '../player/role.dart';
import '../utils/game_logger.dart';
import '../utils/config_loader.dart';

/// 控制台颜色枚举
enum ConsoleColor {
  reset,
  black,
  red,
  green,
  yellow,
  blue,
  magenta,
  cyan,
  white,
  brightBlack,
  brightRed,
  brightGreen,
  brightYellow,
  brightBlue,
  brightMagenta,
  brightCyan,
  brightWhite;

  String get code {
    switch (this) {
      case reset:
        return '\x1B[0m';
      case black:
        return '\x1B[30m';
      case red:
        return '\x1B[31m';
      case green:
        return '\x1B[32m';
      case yellow:
        return '\x1B[33m';
      case blue:
        return '\x1B[34m';
      case magenta:
        return '\x1B[35m';
      case cyan:
        return '\x1B[36m';
      case white:
        return '\x1B[37m';
      case brightBlack:
        return '\x1B[90m';
      case brightRed:
        return '\x1B[91m';
      case brightGreen:
        return '\x1B[92m';
      case brightYellow:
        return '\x1B[93m';
      case brightBlue:
        return '\x1B[94m';
      case brightMagenta:
        return '\x1B[95m';
      case brightCyan:
        return '\x1B[96m';
      case brightWhite:
        return '\x1B[97m';
    }
  }
}

/// 控制台界面管理器
class ConsoleUI {
  ConsoleUI({
    required this.config,
    required this.logger,
    this.consoleWidth = 80,
    this.useColors = true,
  }) {
    _setupConsoleEncoding();
    inputHandler = InputHandler(logger: logger);
    animation = AnimationService(useColors: useColors);
  }
  final GameConfig config;
  final GameLogger logger;
  final int consoleWidth;
  final bool useColors;

  late final InputHandler inputHandler;
  late final AnimationService animation;

  /// 设置控制台编码以支持中文
  void _setupConsoleEncoding() {
    // 主要的乱码问题已通过修复打字机效果解决
    // 这里确保输出缓冲区正确处理UTF-8
    stdout.writeln(); // 刷新输出流
  }

  /// 清屏
  void clear() {
    print('\x1B[2J\x1B[0;0H');
  }

  /// 显示横幅
  void showBanner(String text, {ConsoleColor color = ConsoleColor.cyan}) {
    final banner = _createBanner(text);
    print(_withColor(banner, color));
  }

  /// 显示游戏开始界面
  Future<void> showGameStart(GameState state) async {
    clear();
    showBanner('🐺 狼人杀游戏 🌙', color: ConsoleColor.brightCyan);

    showSection('游戏配置');
    print('玩家数量: ${state.players.length}');
    print('角色配置:');
    state.players.groupBy((p) => p.role.name).forEach((role, players) {
      print('  $role: ${players.length}人');
    });

    showSection('游戏规则');
    print('• 狼人每晚可以击杀一名玩家');
    print('• 好人阵营需要通过投票找出所有狼人');
    print('• 狼人阵营需要淘汰足够的好人');
    print('• 神职角色拥有特殊技能');
    print('• 游戏将持续到某一阵营获胜');

    await waitForUserInput('\n按回车键开始游戏...');
  }

  /// 显示夜晚阶段
  Future<void> showNightPhase(GameState state) async {
    clear();
    showBanner('🌙 第 ${state.dayNumber} 夜', color: ConsoleColor.blue);

    showSection('夜晚降临');
    print('天黑请闭眼...');

    showSection('夜晚行动');

    // Show werewolf actions
    final werewolves =
        state.alivePlayers.where((p) => p.role.isWerewolf).toList();
    if (werewolves.isNotEmpty) {
      print('🐺 狼人正在选择击杀目标...');
    }

    // Show guard actions
    final guards =
        state.alivePlayers.where((p) => p.role is GuardRole).toList();
    if (guards.isNotEmpty) {
      print('🛡️ 守卫正在选择守护目标...');
    }

    // Show seer actions
    final seers = state.alivePlayers.where((p) => p.role is SeerRole).toList();
    if (seers.isNotEmpty) {
      print('🔮 预言家正在查验身份...');
    }

    // Show witch actions
    final witches =
        state.alivePlayers.where((p) => p.role is WitchRole).toList();
    if (witches.isNotEmpty) {
      print('🧪 女巫正在考虑用药...');
    }

    await waitForUserInput('\n按回车键继续...');
  }

  /// 显示白天阶段
  Future<void> showDayPhase(GameState state) async {
    clear();
    showBanner('☀️ 第 ${state.dayNumber} 天', color: ConsoleColor.yellow);

    showSection('天亮了');

    // Show night results
    final deathsTonight = state.eventHistory
        .where((e) => e.type == GameEventType.playerDeath)
        .toList();

    if (deathsTonight.isEmpty) {
      print('🎉 平安夜，无人死亡！');
    } else {
      print('💀 昨晚有玩家死亡：');
      for (final death in deathsTonight) {
        final victim = death.target;
        if (victim != null) {
          print('  • ${victim.name} - ${death.description}');
        } else {
          print('  • ${death.description}');
        }
      }
    }

    showSection('存活玩家');
    _showPlayerList(state.alivePlayers);

    showSection('讨论阶段');
    // 注意：不在这里调用 _showDiscussion，让游戏引擎控制讨论流程
  }

  /// 显示投票阶段
  Future<void> showVotingPhase(GameState state) async {
    clear();
    showBanner('🗳️ 投票阶段', color: ConsoleColor.magenta);

    showSection('投票处决');
    print('请投票选出要处决的玩家...');

    // Show voting process
    final alivePlayers = state.alivePlayers;
    for (int i = 0; i < alivePlayers.length; i++) {
      final player = alivePlayers[i];
      print('${player.name} 投票中...');
    }

    // Show voting results
    final voteResults = state.getVoteResults();
    if (voteResults.isNotEmpty) {
      showSection('投票结果');
      voteResults.forEach((playerId, votes) {
        final player = state.getPlayerById(playerId);
        if (player != null) {
          final percentage =
              (votes / state.totalVotes * 100).toStringAsFixed(1);
          print('[${player.name}]: $votes 票 ($percentage%)');
        }
      });

      final executed = state.getVoteTarget();
      if (executed != null) {
        print('\n⚰️ ${executed.name} 被投票处决！');
        print('身份: ${executed.role.name}');
      } else {
        print('\n🤝 投票未达成一致，无人被处决');
      }
    }

    await waitForUserInput('\n按回车键继续...');
  }

  /// 显示游戏结束
  Future<void> showGameEnd(GameState state) async {
    clear();
    showBanner('🎊 游戏结束', color: ConsoleColor.brightGreen);

    showSection('游戏结果');
    final winnerColor =
        state.winner == '好人' ? ConsoleColor.green : ConsoleColor.red;
    print(_withColor('🏆 获胜阵营: ${state.winner}', winnerColor));

    showSection('玩家身份揭晓');
    for (final player in state.players) {
      final statusIcon = player.isAlive ? '💚' : '💀';
      final roleColor =
          player.role.isEvil ? ConsoleColor.red : ConsoleColor.green;
      final statusText = player.isAlive ? '存活' : '死亡';

      print(_withColor(
          '$statusIcon ${player.name} - ${player.role.name} ($statusText)',
          roleColor));
    }

    showSection('游戏统计');
    final duration = state.lastUpdateTime!.difference(state.startTime);
    print('游戏时长: ${duration.inMinutes}分${duration.inSeconds % 60}秒');
    print('总天数: ${state.dayNumber} 天');
    print('存活玩家: ${state.alivePlayers.length} 人');
    print('死亡玩家: ${state.deadPlayers.length} 人');

    // Show game summary
    showSection('事件回顾');
    final importantEvents = state.eventHistory
        .where((e) =>
            e.type == GameEventType.playerDeath ||
            e.type == GameEventType.gameStart ||
            e.type == GameEventType.gameEnd)
        .take(10)
        .toList();

    for (final event in importantEvents) {
      final time = event.timestamp.toString().substring(11, 16);
      print('[$time] ${event.description}');
    }

    await waitForUserInput('\n按回车键退出...');
  }

  /// 显示游戏状态
  void showGameState(GameState state) {
    print('\n${'=' * consoleWidth}');
    print(
        '游戏状态: ${state.status.displayName} | 第${state.dayNumber}天 | ${state.currentPhase.displayName}');
    print(
        '存活: ${state.alivePlayers.length}人 | 死亡: ${state.deadPlayers.length}人');
    if (state.winner != null) {
      print('获胜阵营: ${state.winner}');
    }
    print('=' * consoleWidth);
  }

  /// 显示玩家列表
  void _showPlayerList(List<Player> players) {
    for (int i = 0; i < players.length; i++) {
      final player = players[i];
      final status = player.isAlive ? '💚' : '💀';

      print(
          '${i + 1}. ${_withColor('$status ${player.name}', ConsoleColor.white)}');
    }
  }

  /// 显示章节
  void showSection(String title, {int duration = 0}) {
    if (duration > 0) {
      Future.delayed(Duration(milliseconds: duration));
    }
    print('\n${_withColor('=== $title ===', ConsoleColor.brightYellow)}');
  }

  /// 创建横幅
  String _createBanner(String text) {
    final padding = (consoleWidth - text.length - 4) ~/ 2;
    final line = '═' * consoleWidth;
    final paddedText = '║${' ' * padding}$text${' ' * padding}║';

    // Ensure proper length
    if (paddedText.length > consoleWidth) {
      return '$line\n${paddedText.substring(0, consoleWidth - 1)}║\n$line';
    }

    return '$line\n$paddedText\n$line';
  }

  /// 打字机效果
  Future<void> typewriterEffect(
    String text, {
    int duration = 50,
    ConsoleColor color = ConsoleColor.white,
    bool newline = true,
  }) async {
    // 修复中文乱码：改为按词组输出而不是逐字符输出
    final words = _splitTextIntoWords(text);

    for (final word in words) {
      stdout.write(_withColor(word, color));
      await Future.delayed(Duration(milliseconds: duration));
    }

    if (newline) {
      print('');
    }
  }

  /// 将文本分割为适合显示的词组（处理中文字符）
  List<String> _splitTextIntoWords(String text) {
    final result = <String>[];
    final currentWord = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      // 中文字符、标点符号或英文单词
      if (_isChineseChar(char) || _isPunctuation(char)) {
        if (currentWord.isNotEmpty &&
            !_isChineseChar(currentWord.toString()[0])) {
          result.add(currentWord.toString());
          currentWord.clear();
        }
        currentWord.write(char);
      }
      // 英文字符
      else if (_isEnglishChar(char)) {
        if (currentWord.isNotEmpty &&
            _isChineseChar(currentWord.toString()[0])) {
          result.add(currentWord.toString());
          currentWord.clear();
        }
        currentWord.write(char);
      }
      // 空格或其他分隔符
      else {
        if (currentWord.isNotEmpty) {
          result.add(currentWord.toString());
          currentWord.clear();
        }
        result.add(char);
      }
    }

    if (currentWord.isNotEmpty) {
      result.add(currentWord.toString());
    }

    return result;
  }

  /// 检查是否是中文字符
  bool _isChineseChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF) || // 基本汉字
        (code >= 0x3400 && code <= 0x4DBF) || // 扩展A
        (code >= 0x20000 && code <= 0x2A6DF) || // 扩展B
        (code >= 0x2A700 && code <= 0x2B73F) || // 扩展C
        (code >= 0x2B740 && code <= 0x2B81F) || // 扩展D
        (code >= 0x2B820 && code <= 0x2CEAF) || // 扩展E
        (code >= 0xF900 && code <= 0xFAFF) || // 兼容汉字
        (code >= 0x2F800 && code <= 0x2FA1F); // 兼容补充
  }

  /// 检查是否是英文字符
  bool _isEnglishChar(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 0x0041 && code <= 0x005A) || // 大写字母
        (code >= 0x0061 && code <= 0x007A) || // 小写字母
        (code >= 0x0030 && code <= 0x0039); // 数字
  }

  /// 检查是否是标点符号
  bool _isPunctuation(String char) {
    return '，。！？；：""' '（）【】《》…—·、'.contains(char);
  }

  /// 等待用户输入
  Future<void> waitForUserInput(String message) async {
    print(message);
    await inputHandler.waitForEnter();
  }

  /// 应用颜色
  String _withColor(String text, ConsoleColor color) {
    if (!useColors) return text;
    return '${color.code}$text${ConsoleColor.reset.code}';
  }

  /// 显示进度条
  Future<void> showProgress(double progress, {String message = ''}) {
    return animation.showProgress(progress, message: message);
  }

  /// 显示错误信息
  void showError(String message) {
    print(_withColor('❌ 错误: $message', ConsoleColor.red));
  }

  /// 显示成功信息
  void showSuccess(String message) {
    print(_withColor('✅ $message', ConsoleColor.green));
  }

  /// 显示警告信息
  void showWarning(String message) {
    print(_withColor('⚠️ $message', ConsoleColor.yellow));
  }

  /// 显示信息
  void showInfo(String message) {
    print(_withColor('ℹ️ $message', ConsoleColor.cyan));
  }
}

/// 输入处理器
class InputHandler {
  InputHandler({required this.logger});
  final GameLogger logger;

  /// 等待回车键
  Future<void> waitForEnter() async {
    try {
      stdin.readLineSync();
    } catch (e) {
      // 如果输入流已经关闭，忽略错误
      logger.warning('输入流错误: $e');
    }
  }

  /// 等待用户输入
  Future<String> waitForInput(String prompt) async {
    stdout.write(prompt);
    final input = stdin.readLineSync();
    return input ?? '';
  }

  /// 等待确认
  Future<bool> waitForConfirmation(String message) async {
    final input = await waitForInput('$message (Y/N): ');
    return input.toLowerCase() == 'y' || input.toLowerCase() == 'yes';
  }

  /// 等待数字选择
  Future<int> waitForSelection(String message, int max) async {
    while (true) {
      final input = await waitForInput(message);
      try {
        final selection = int.parse(input);
        if (selection >= 1 && selection <= max) {
          return selection - 1;
        }
      } catch (e) {
        // 无效输入，继续循环
      }
      print('请输入 1-$max 之间的数字');
    }
  }

  /// 解析命令
  Future<UserCommand> parseCommand(String input) async {
    final parts = input.trim().split(' ');
    final command = parts[0].toLowerCase();
    final args = parts.skip(1).toList();

    switch (command) {
      case 'start':
      case 's':
        return UserCommand(type: CommandType.start, args: args);
      case 'pause':
      case 'p':
        return UserCommand(type: CommandType.pause, args: args);
      case 'resume':
      case 'r':
        return UserCommand(type: CommandType.resume, args: args);
      case 'stop':
      case 'quit':
      case 'q':
        return UserCommand(type: CommandType.quit, args: args);
      case 'help':
      case 'h':
        return UserCommand(type: CommandType.help, args: args);
      case 'status':
        return UserCommand(type: CommandType.status, args: args);
      case 'speed':
        return UserCommand(type: CommandType.speed, args: args);
      default:
        return UserCommand(type: CommandType.unknown, args: args);
    }
  }
}

/// 用户命令
enum CommandType {
  start,
  pause,
  resume,
  quit,
  help,
  status,
  speed,
  unknown,
}

class UserCommand {
  UserCommand({required this.type, required this.args});
  final CommandType type;
  final List<String> args;
}

/// 动画服务
class AnimationService {
  AnimationService({this.useColors = true});
  final bool useColors;

  Future<void> showProgress(double progress, {String message = ''}) async {
    const width = 30;
    const filled = '█';
    const empty = '░';

    final filledWidth = (progress * width).round();
    final emptyWidth = width - filledWidth;

    final bar = '[${filled * filledWidth}${empty * emptyWidth}]';
    final percentage = (progress * 100).toStringAsFixed(1);

    final messagePart = message.isNotEmpty ? ' $message' : '';
    final fullMessage = '\r$bar $percentage%$messagePart';

    stdout.write(fullMessage);

    if (progress >= 1.0) {
      print(''); // New line when complete
    }

    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> showLoading(
      {String message = '加载中...',
      Duration duration = const Duration(seconds: 2)}) async {
    final frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < duration) {
      for (final frame in frames) {
        stdout.write('\r$frame $message');
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Clear the loading animation
    stdout.write('\r${' ' * (message.length + 2)}\r');
  }
}

// Extension for grouping
extension ListExtension<T> on List<T> {
  Map<K, List<T>> groupBy<K>(K Function(T) key) {
    final map = <K, List<T>>{};
    for (final item in this) {
      final k = key(item);
      map.putIfAbsent(k, () => []).add(item);
    }
    return map;
  }
}
