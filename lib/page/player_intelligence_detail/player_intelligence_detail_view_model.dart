import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:werewolf_arena/database/player_intelligence_repository.dart';
import 'package:werewolf_arena/entity/player_intelligence_entity.dart';
import 'package:werewolf_arena/page/player_intelligence/player_intelligence_view_model.dart';

class PlayerIntelligenceDetailViewModel {
  final urlController = TextEditingController();
  final keyController = TextEditingController();
  final modelController = TextEditingController();

  var _id = 0;

  void initSignals(PlayerIntelligenceEntity intelligence) {
    _id = intelligence.id;
    urlController.text = intelligence.baseUrl;
    keyController.text = intelligence.apiKey;
    modelController.text = intelligence.modelId;
  }

  void dispose() {
    urlController.dispose();
    keyController.dispose();
    modelController.dispose();
  }

  void save(BuildContext context) {
    if (modelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Model Id is required')));
      return;
    }
    if (_id == 0) {
      storePlayerIntelligence(context);
    } else {
      updatePlayerIntelligence(context);
    }
    final viewModel = GetIt.instance.get<PlayerIntelligenceViewModel>();
    viewModel.refreshPlayerIntelligences();
    Navigator.of(context).pop();
  }

  void storePlayerIntelligence(BuildContext context) {
    final intelligence = PlayerIntelligenceEntity()
      ..baseUrl = urlController.text
      ..apiKey = keyController.text
      ..modelId = modelController.text;
    PlayerIntelligenceRepository().storePlayerIntelligence(intelligence);
  }

  void updatePlayerIntelligence(BuildContext context) {
    final intelligence = PlayerIntelligenceEntity()
      ..id = _id
      ..baseUrl = urlController.text
      ..apiKey = keyController.text
      ..modelId = modelController.text;
    PlayerIntelligenceRepository().updatePlayerIntelligence(intelligence);
  }
}
