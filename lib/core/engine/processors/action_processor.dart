
import '../../state/game_state.dart';

/// The abstract base class for all action processors.
///
/// An action processor is responsible for handling the logic of a specific player action
/// during a game phase (e.g., werewolf kill, seer investigate).
abstract class ActionProcessor {
  /// Processes a player action.
  ///
  /// This method contains the logic for a specific action, such as validating the action,
  /// updating the game state, and generating events.
  ///
  /// - [state]: The current [GameState] of the game.
  Future<void> process(GameState state);
}
