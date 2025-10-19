import 'package:werewolf_arena/engine/game_observer.dart';
import 'package:werewolf_arena/engine/game_state.dart';

/// The abstract base class for all phase processors.
///
/// A phase processor is responsible for handling the logic of a specific game phase
/// (e.g., night, day, voting).
abstract class GameProcessor {
  /// Processes the current game phase.
  ///
  /// This method contains the core logic for the phase, such as collecting actions,
  /// resolving them, and generating events.
  ///
  /// - [state]: The current [GameState] of the game.
  Future<void> process(GameState state, {GameObserver? observer});
}
