import 'package:werewolf_arena/engine/player/game_player.dart';

abstract class GameEvent {
  final String id;
  final int day;
  final List<String> visibility;

  GameEvent({this.day = 0, this.visibility = const []})
    : id = DateTime.now().millisecondsSinceEpoch.toString();

  bool isVisibleTo(GamePlayer player) {
    return visibility.contains(player.role.id);
  }

  String toNarrative();

  @override
  String toString() {
    return 'GameEvent($id)';
  }
}
