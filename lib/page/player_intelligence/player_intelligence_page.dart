import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/page/player_intelligence/player_intelligence_view_model.dart';

@RoutePage()
class PlayerIntelligencePage extends StatefulWidget {
  const PlayerIntelligencePage({super.key});

  @override
  State<PlayerIntelligencePage> createState() => _PlayerIntelligencePageState();
}

class _PlayerIntelligencePageState extends State<PlayerIntelligencePage> {
  final PlayerIntelligenceViewModel viewModel = GetIt.instance
      .get<PlayerIntelligenceViewModel>();

  // 文本编辑控制器
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;

  @override
  void initState() {
    super.initState();
    viewModel.initSignals();

    // 初始化控制器
    _apiKeyController = TextEditingController(
      text: viewModel.defaultApiKey.value,
    );
    _baseUrlController = TextEditingController(
      text: viewModel.defaultBaseUrl.value,
    );

    // 监听 signal 变化并更新控制器
    effect(() {
      if (_apiKeyController.text != viewModel.defaultApiKey.value) {
        _apiKeyController.text = viewModel.defaultApiKey.value;
      }
    });

    effect(() {
      if (_baseUrlController.text != viewModel.defaultBaseUrl.value) {
        _baseUrlController.text = viewModel.defaultBaseUrl.value;
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Intelligence'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => viewModel.navigateBack(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _showResetDialog(),
          ),
        ],
      ),
      body: Watch((context) {
        final isLoading = viewModel.isLoading.value;

        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return _buildConfigContent();
      }),
    );
  }

  Widget _buildConfigContent() {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'Default',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ListTile(
          title: const Text('Base Url'),
          subtitle: Text(viewModel.defaultBaseUrl.value),
          onTap: () {},
        ),
        ListTile(
          title: const Text('API Key'),
          subtitle: Text(
            viewModel.defaultApiKey.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {},
        ),
        ListTile(
          title: const Text('Model Id'),
          subtitle: Text(viewModel.llmModels.value.first),
          onTap: () {},
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Available',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('Add Player Intelligence'),
              ),
            ],
          ),
        ),
        ...viewModel.llmModels.value.map(
          (model) => ListTile(title: Text(model), onTap: () {}),
        ),
      ],
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置配置'),
        content: const Text('确定要重置为默认配置吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              viewModel.resetToDefaults();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('配置已重置')));
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
