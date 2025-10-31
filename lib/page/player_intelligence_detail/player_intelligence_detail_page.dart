import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:werewolf_arena/entity/player_intelligence_entity.dart';
import 'package:werewolf_arena/page/player_intelligence_detail/player_intelligence_detail_view_model.dart';

@RoutePage()
class PlayerIntelligenceDetailPage extends StatefulWidget {
  final PlayerIntelligenceEntity intelligence;
  const PlayerIntelligenceDetailPage({super.key, required this.intelligence});

  @override
  State<PlayerIntelligenceDetailPage> createState() =>
      _PlayerIntelligenceDetailPageState();
}

class _PlayerIntelligenceDetailPageState
    extends State<PlayerIntelligenceDetailPage> {
  final viewModel = GetIt.instance.get<PlayerIntelligenceDetailViewModel>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Player Intelligence Detail')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          TextField(
            controller: viewModel.urlController,
            decoration: InputDecoration(labelText: 'Base Url'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: viewModel.keyController,
            decoration: InputDecoration(labelText: 'API Key'),
          ),
          const SizedBox(height: 16),
          Text(
            'Base url and API key are optional, and the default values will be used if not provided.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: viewModel.modelController,
            decoration: InputDecoration(
              labelText: 'Model Id *',
              helperText: 'Required',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 16,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => viewModel.save(context),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    viewModel.initSignals(widget.intelligence);
  }
}
