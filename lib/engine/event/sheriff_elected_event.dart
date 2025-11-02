import 'package:werewolf_arena/engine/event/game_event.dart';

/// 当选警长事件 - 宣布警长当选结果
class SheriffElectedEvent extends GameEvent {
  final String? sheriffName;
  final Map<String, int> voteResults;
  final bool isRunoff; // 是否为流局(无警长)

  SheriffElectedEvent({
    required this.sheriffName,
    required this.voteResults,
    this.isRunoff = false,
    required super.day,
  }) : super(visibility: ['public']);

  @override
  String toNarrative() {
    if (isRunoff) {
      return '警长竞选流局，本局无警长';
    }

    final voteSummary = voteResults.entries
        .map((e) => '${e.key}: ${e.value}票')
        .join(', ');

    return sheriffName != null
        ? '$sheriffName 当选为警长！ 投票结果：$voteSummary'
        : '警长竞选结束，投票结果：$voteSummary';
  }
}
