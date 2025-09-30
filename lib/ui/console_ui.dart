import 'dart:async';
import 'dart:io';
import '../game/game_state.dart';
import '../game/game_action.dart';
import '../player/player.dart';
import '../player/role.dart';
import '../utils/game_logger.dart';
import '../utils/config_loader.dart';

/// Console color enumeration
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

/// Console interface manager
class ConsoleUI {
  ConsoleUI({
    required this.config,
    required this.logger,
    this.consoleWidth = 80,
    this.useColors = true,
  }) {
    _setupConsoleEncoding();
    inputHandler = InputHandler(logger: logger);
  }
  final GameConfig config;
  final GameLogger logger;
  final int consoleWidth;
  final bool useColors;

  late final InputHandler inputHandler;

  /// Setup console encoding to support Chinese characters
  void _setupConsoleEncoding() {
    // Main encoding issues resolved through typewriter effect fixes
    // Ensure output buffer correctly handles UTF-8
    stdout.writeln(); // Flush output stream
  }

  /// Clear screen
  void clear() {
    print('\x1B[2J\x1B[0;0H');
  }

  /// Display banner
  void showBanner(String text, {ConsoleColor color = ConsoleColor.cyan}) {
    final banner = _createBanner(text);
    print(_withColor(banner, color));
  }

  /// Display game start interface
  Future<void> showGameStart(GameState state) async {
    clear();
    showBanner('🐺 Werewolf Game 🌙', color: ConsoleColor.brightCyan);
  }

  /// Display night phase
  Future<void> showNightPhase(GameState state) async {
    clear();
    showBanner('🌙 Night ${state.dayNumber}', color: ConsoleColor.blue);

    // Show guard actions
    final guards =
        state.alivePlayers.where((p) => p.role is GuardRole).toList();
    if (guards.isNotEmpty) {
      print('🛡️ Guard is choosing protection target...');
    }

    // Show werewolf actions
    final werewolves =
        state.alivePlayers.where((p) => p.role.isWerewolf).toList();
    if (werewolves.isNotEmpty) {
      print('🐺 Werewolf is choosing kill target...');
    }

    // Show seer actions
    final seers = state.alivePlayers.where((p) => p.role is SeerRole).toList();
    if (seers.isNotEmpty) {
      print('🔮 Seer is investigating identity...');
    }

    // Show witch actions
    final witches =
        state.alivePlayers.where((p) => p.role is WitchRole).toList();
    if (witches.isNotEmpty) {
      print('🧪 Witch is considering using potions...');
    }

    await waitForUserInput('\nPress Enter to continue...');
  }

  /// Display day phase
  Future<void> showDayPhase(GameState state) async {
    clear();
    showBanner('☀️ Day ${state.dayNumber}', color: ConsoleColor.yellow);

    showSection('Daybreak');

    // Show night results
    final deathsTonight = state.eventHistory
        .where((e) => e.type == GameEventType.playerDeath)
        .toList();

    if (deathsTonight.isEmpty) {
      print('🎉 Peaceful night, no deaths!');
    } else {
      print('💀 Players died last night:');
      for (final death in deathsTonight) {
        final victim = death.target;
        if (victim != null) {
          print('  • ${victim.name} - ${death.description}');
        } else {
          print('  • ${death.description}');
        }
      }
    }

    showSection('Alive Players');
    _showPlayerList(state.alivePlayers);

    showSection('Discussion Phase');
    // Note: Don't call _showDiscussion here, let game engine control discussion flow
  }

  /// Display voting phase
  Future<void> showVotingPhase(GameState state) async {
    clear();
    showBanner('🗳️ Voting Phase', color: ConsoleColor.magenta);

    showSection('Vote Execution');
    print('Please vote for the player to execute...');

    // Show voting process
    final alivePlayers = state.alivePlayers;
    for (int i = 0; i < alivePlayers.length; i++) {
      final player = alivePlayers[i];
      print('${player.name} is voting...');
    }

    // Show voting results
    final voteResults = state.getVoteResults();
    if (voteResults.isNotEmpty) {
      showSection('Voting Results');
      voteResults.forEach((playerId, votes) {
        final player = state.getPlayerById(playerId);
        if (player != null) {
          final percentage =
              (votes / state.totalVotes * 100).toStringAsFixed(1);
          print('[${player.name}]: $votes votes ($percentage%)');
        }
      });

      final executed = state.getVoteTarget();
      if (executed != null) {
        print('\n⚰️ ${executed.name} was executed by vote!');
        print('Role: ${executed.role.name}');
      } else {
        print('\n🤝 Vote inconclusive, no execution');
      }
    }

    await waitForUserInput('\nPress Enter to continue...');
  }

  /// Display game end
  Future<void> showGameEnd(GameState state) async {
    clear();
    showBanner('🎊 Game Over', color: ConsoleColor.brightGreen);

    showSection('Game Result');
    final winnerColor =
        state.winner == 'Good' ? ConsoleColor.green : ConsoleColor.red;
    print(_withColor('🏆 Winning faction: ${state.winner}', winnerColor));

    showSection('Player Role Reveals');
    for (final player in state.players) {
      final statusIcon = player.isAlive ? '💚' : '💀';
      final roleColor =
          player.role.isEvil ? ConsoleColor.red : ConsoleColor.green;
      final statusText = player.isAlive ? 'Alive' : 'Dead';

      print(_withColor(
          '$statusIcon ${player.name} - ${player.role.name} ($statusText)',
          roleColor));
    }

    showSection('Game Statistics');
    final duration = state.lastUpdateTime!.difference(state.startTime);
    print('Game duration: ${duration.inMinutes}m ${duration.inSeconds % 60}s');
    print('Total days: ${state.dayNumber} days');
    print('Alive players: ${state.alivePlayers.length} players');
    print('Dead players: ${state.deadPlayers.length} players');

    // Show game summary
    showSection('Event Review');
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

    await waitForUserInput('\nPress Enter to exit...');
  }

  /// Display game status
  void showGameState(GameState state) {
    print('\n${'=' * consoleWidth}');
    print(
        'Game Status: ${state.status.displayName} | Day ${state.dayNumber} | ${state.currentPhase.displayName}');
    print(
        'Alive: ${state.alivePlayers.length} players | Dead: ${state.deadPlayers.length} players');
    if (state.winner != null) {
      print('Winning faction: ${state.winner}');
    }
    print('=' * consoleWidth);
  }

  /// Show player list
  void _showPlayerList(List<Player> players) {
    for (int i = 0; i < players.length; i++) {
      final player = players[i];
      final status = player.isAlive ? '💚' : '💀';

      print(
          '${i + 1}. ${_withColor('$status ${player.name}', ConsoleColor.white)}');
    }
  }

  /// Show section
  void showSection(String title, {int duration = 0}) {
    if (duration > 0) {
      Future.delayed(Duration(milliseconds: duration));
    }
    print('\n${_withColor('=== $title ===', ConsoleColor.brightYellow)}');
  }

  /// Create banner
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

  /// Wait for user input
  Future<void> waitForUserInput(String message) async {
    print(message);
    await inputHandler.waitForEnter();
  }

  /// Apply color
  String _withColor(String text, ConsoleColor color) {
    if (!useColors) return text;
    return '${color.code}$text${ConsoleColor.reset.code}';
  }


  /// Show error message
  void showError(String message) {
    print(_withColor('❌ Error: $message', ConsoleColor.red));
  }

  /// Show success message
  void showSuccess(String message) {
    print(_withColor('✅ $message', ConsoleColor.green));
  }

  /// Show warning message
  void showWarning(String message) {
    print(_withColor('⚠️ $message', ConsoleColor.yellow));
  }

  /// Show info message
  void showInfo(String message) {
    print(_withColor('ℹ️ $message', ConsoleColor.cyan));
  }
}

/// Input handler
class InputHandler {
  InputHandler({required this.logger});
  final GameLogger logger;

  /// Wait for Enter key
  Future<void> waitForEnter() async {
    try {
      stdin.readLineSync();
    } catch (e) {
      // Ignore error if input stream is already closed
      logger.warning('Input stream error: $e');
    }
  }

  /// Wait for user input
  Future<String> waitForInput(String prompt) async {
    stdout.write(prompt);
    final input = stdin.readLineSync();
    return input ?? '';
  }

  /// Wait for confirmation
  Future<bool> waitForConfirmation(String message) async {
    final input = await waitForInput('$message (Y/N): ');
    return input.toLowerCase() == 'y' || input.toLowerCase() == 'yes';
  }

  /// Wait for number selection
  Future<int> waitForSelection(String message, int max) async {
    while (true) {
      final input = await waitForInput(message);
      try {
        final selection = int.parse(input);
        if (selection >= 1 && selection <= max) {
          return selection - 1;
        }
      } catch (e) {
        // Invalid input, continue loop
      }
      print('Please enter a number between 1-$max');
    }
  }

  /// Parse command
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

/// User command
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
