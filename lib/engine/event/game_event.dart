import 'package:werewolf_arena/engine/player/game_player.dart';

abstract class GameEvent {
  final String id;
  final int day;
  final List<String> visibility;

  GameEvent({this.day = 0, this.visibility = const []})
    : id = DateTime.now().millisecondsSinceEpoch.toString();

  bool isVisibleTo(GamePlayer player) {
    if (visibility.contains('public')) {
      return true;
    }

    if (visibility.isEmpty) {
      return false;
    }

    return visibility.contains(player.role.id);
  }

  String toNarrative();

  @override
  String toString() => 'GameEvent($id)';
}
