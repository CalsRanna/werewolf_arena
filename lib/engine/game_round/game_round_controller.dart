import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// The abstract base class for all round controllers.
///
/// A round controller is responsible for handling the logic of a complete game round,
/// including night phase, day phase, and memory updates.
abstract class GameRoundController {
  /// Processes a complete game round.
  ///
  /// This method contains the core logic for the round, such as:
  /// - Night phase: werewolf actions, seer investigation, witch actions, guard protection
  /// - Day phase: discussions, voting, executions
  /// - Memory updates: updating AI player memories after the round
  ///
  /// - [state]: The current [GameState] of the game.
  Future<void> tick(GameState state, {GameObserver? observer});
}
