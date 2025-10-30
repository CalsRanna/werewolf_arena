abstract class AIPlayerPersona {
  final String name;
  final String description;
  // 用于塑造AI对自我身份的认知
  final String coreSetting;
  // 决定AI“做什么”，是其决策的核心依据
  final String behavioralLogic;
  // 决定AI“怎么说”，是其行为的外在表现
  final String languageStyle;
  // 决定AI“怎么记”，影响其后续决策
  final String memoryDirective;
  final String gameSlang;
  final String situationalReactions;

  const AIPlayerPersona({
    required this.name,
    required this.description,
    required this.coreSetting,
    required this.behavioralLogic,
    required this.languageStyle,
    required this.memoryDirective,
    required this.gameSlang,
    required this.situationalReactions,
  });
}
