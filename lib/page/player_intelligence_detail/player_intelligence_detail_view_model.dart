import 'package:flutter/material.dart';
import 'package:werewolf_arena/engine/game_config.dart';

class PlayerIntelligenceDetailViewModel {
  final urlController = TextEditingController();
  final keyController = TextEditingController();
  final modelController = TextEditingController();

  void initSignals(PlayerIntelligence intelligence) {
    urlController.text = intelligence.baseUrl;
    keyController.text = intelligence.apiKey;
    modelController.text = intelligence.modelId;
  }

  void dispose() {
    urlController.dispose();
    keyController.dispose();
    modelController.dispose();
  }

  void storePlayerIntelligence(BuildContext context) {
    final intelligence = PlayerIntelligence(
      baseUrl: urlController.text,
      apiKey: keyController.text,
      modelId: modelController.text,
    );
    Navigator.of(context).pop(intelligence);
  }
}
