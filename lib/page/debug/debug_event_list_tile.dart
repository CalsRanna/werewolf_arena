import 'package:flutter/material.dart';
import 'package:werewolf_arena/engine/event/announce_event.dart';
import 'package:werewolf_arena/engine/event/conspire_event.dart';
import 'package:werewolf_arena/engine/event/discuss_event.dart';
import 'package:werewolf_arena/engine/event/game_event.dart';

class DebugEventListTile extends StatelessWidget {
  final GameEvent event;
  const DebugEventListTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary,
          ),
          height: 8,
          margin: EdgeInsets.only(top: 6),
          width: 8,
        ),
        Expanded(child: Text(_getContent())),
      ],
    );
  }

  String _getContent() {
    return switch (event) {
      AnnounceEvent e => '[JUDGE]：${e.message}',
      ConspireEvent e => e.message,
      DiscussEvent e => '[${e.source.name}]： ${e.message}',
      _ => '[SYSTEM]：${event.toNarrative()}',
    };
  }
}
