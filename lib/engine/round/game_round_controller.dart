import 'package:werewolf_arena/engine/game.dart';
import 'package:werewolf_arena/engine/game_observer.dart';

/// The abstract base class for all round controllers.
///
/// A round controller is responsible for handling the logic of a complete game round,
/// including night, day, and memory updates.
abstract class GameRoundController {
  /// Processes a complete game round.
  ///
  /// This method contains the core logic for the round, such as:
  /// - Night: werewolf actions, seer investigation, witch actions, guard protection
  /// - Day: discussions, voting, executions
  /// - Memory updates: updating AI player memories after the round
  ///
  /// - [game]: The current [Game] instance.
  Future<void> tick(Game game, {GameObserver? observer});
}
