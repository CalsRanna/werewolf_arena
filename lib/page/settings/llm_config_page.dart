import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/page/settings/llm_config_view_model.dart';
import 'package:werewolf_arena/services/config/config.dart';

@RoutePage()
class LLMConfigPage extends StatefulWidget {
  const LLMConfigPage({super.key});

  @override
  State<LLMConfigPage> createState() => _LLMConfigPageState();
}

class _LLMConfigPageState extends State<LLMConfigPage> {
  final LLMConfigViewModel viewModel = GetIt.instance.get<LLMConfigViewModel>();

  @override
  void initState() {
    super.initState();
    viewModel.initSignals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LLM 配置'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => viewModel.navigateBack(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () => viewModel.saveConfig(context),
            tooltip: '保存配置',
          ),
        ],
      ),
      body: Watch((context) {
        final isLoading = viewModel.isLoading.value;

        if (isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        return _buildConfigContent();
      }),
    );
  }

  Widget _buildConfigContent() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // 说明文本
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '关于 LLM 配置',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '配置 AI 玩家使用的语言模型。可以为每个玩家设置不同的模型，让游戏更有趣。',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 24),

        // 默认配置
        _buildSection('默认 LLM 配置', [
          _buildTextField(
            '模型名称',
            '例如: gpt-3.5-turbo',
            viewModel.defaultModel.value,
            (value) => viewModel.defaultModel.value = value,
          ),
          _buildTextField(
            'API Key',
            '请输入您的 API 密钥',
            viewModel.defaultApiKey.value,
            (value) => viewModel.defaultApiKey.value = value,
            obscureText: true,
          ),
          _buildTextField(
            'Base URL',
            '例如: https://api.openai.com/v1',
            viewModel.defaultBaseUrl.value,
            (value) => viewModel.defaultBaseUrl.value = value,
          ),
          _buildNumberField(
            '超时时间(秒)',
            viewModel.defaultTimeout.value,
            (value) => viewModel.defaultTimeout.value = value,
          ),
          _buildNumberField(
            '最大重试次数',
            viewModel.defaultMaxRetries.value,
            (value) => viewModel.defaultMaxRetries.value = value,
          ),
        ]),

        SizedBox(height: 24),

        // 玩家专属配置
        _buildSection('玩家专属配置', [
          Watch((context) {
            final playerConfigs = viewModel.playerConfigs.value;

            return Column(
              children: [
                ...playerConfigs.entries.map((entry) {
                  return _buildPlayerConfigCard(entry.key, entry.value);
                }),
                SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _showAddPlayerConfigDialog(),
                  icon: Icon(Icons.add),
                  label: Text('添加玩家配置'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                  ),
                ),
              ],
            );
          }),
        ]),

        SizedBox(height: 24),

        // 重置按钮
        OutlinedButton.icon(
          onPressed: () => _showResetDialog(),
          icon: Icon(Icons.restore),
          label: Text('重置为默认配置'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            minimumSize: Size(double.infinity, 48),
          ),
        ),

        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    String value,
    Function(String) onChanged, {
    bool obscureText = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: TextField(
        controller: TextEditingController(text: value)
          ..selection = TextSelection.collapsed(offset: value.length),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(),
        ),
        obscureText: obscureText,
        maxLines: maxLines,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNumberField(String label, int value, Function(int) onChanged) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: TextField(
        controller: TextEditingController(text: value.toString()),
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        onChanged: (text) {
          final intValue = int.tryParse(text);
          if (intValue != null) {
            onChanged(intValue);
          }
        },
      ),
    );
  }

  Widget _buildPlayerConfigCard(String playerId, PlayerLLMConfig config) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text(playerId)),
        title: Text('玩家 $playerId'),
        subtitle: Text(config.model.isEmpty ? '未设置模型' : config.model),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _showEditPlayerConfigDialog(playerId, config),
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => viewModel.removePlayerConfig(playerId),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPlayerConfigDialog() {
    final playerIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('添加玩家配置'),
        content: TextField(
          controller: playerIdController,
          decoration: InputDecoration(
            labelText: '玩家编号',
            hintText: '例如: 1, 2, 3...',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final playerId = playerIdController.text;
              if (playerId.isNotEmpty) {
                viewModel.addPlayerConfig(playerId);
                Navigator.pop(context);
              }
            },
            child: Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditPlayerConfigDialog(String playerId, PlayerLLMConfig config) {
    final modelController = TextEditingController(text: config.model);
    final apiKeyController = TextEditingController(text: config.apiKey);
    final baseUrlController = TextEditingController(text: config.baseUrl ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('编辑玩家 $playerId 配置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: modelController,
                decoration: InputDecoration(
                  labelText: '模型名称',
                  hintText: '留空使用默认配置',
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: apiKeyController,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: '留空使用默认配置',
                ),
                obscureText: true,
              ),
              SizedBox(height: 16),
              TextField(
                controller: baseUrlController,
                decoration: InputDecoration(
                  labelText: 'Base URL',
                  hintText: '留空使用默认配置',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              viewModel.updatePlayerConfig(
                playerId,
                'model',
                modelController.text,
              );
              viewModel.updatePlayerConfig(
                playerId,
                'apiKey',
                apiKeyController.text,
              );
              viewModel.updatePlayerConfig(
                playerId,
                'baseUrl',
                baseUrlController.text,
              );
              Navigator.pop(context);
            },
            child: Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('重置配置'),
        content: Text('确定要重置所有 LLM 配置为默认值吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              viewModel.resetToDefaults();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('配置已重置')));
            },
            child: Text('确定'),
          ),
        ],
      ),
    );
  }
}
