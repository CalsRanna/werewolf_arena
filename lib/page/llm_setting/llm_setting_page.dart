import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/page/llm_setting/llm_setting_view_model.dart';

@RoutePage()
class LLMSettingPage extends StatefulWidget {
  const LLMSettingPage({super.key});

  @override
  State<LLMSettingPage> createState() => _LLMSettingPageState();
}

class _LLMSettingPageState extends State<LLMSettingPage> {
  final LLMSettingViewModel viewModel = GetIt.instance
      .get<LLMSettingViewModel>();

  // 文本编辑控制器
  late TextEditingController _apiKeyController;
  late TextEditingController _baseUrlController;

  @override
  void initState() {
    super.initState();
    viewModel.initSignals();

    // 初始化控制器
    _apiKeyController = TextEditingController(text: viewModel.llmApiKey.value);
    _baseUrlController = TextEditingController(
      text: viewModel.llmBaseUrl.value,
    );

    // 监听 signal 变化并更新控制器
    effect(() {
      if (_apiKeyController.text != viewModel.llmApiKey.value) {
        _apiKeyController.text = viewModel.llmApiKey.value;
      }
    });

    effect(() {
      if (_baseUrlController.text != viewModel.llmBaseUrl.value) {
        _baseUrlController.text = viewModel.llmBaseUrl.value;
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
        title: const Text('AI 模型配置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => viewModel.navigateBack(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重置为默认配置',
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
      padding: const EdgeInsets.all(16),
      children: [
        // 说明卡片
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '配置 AI 玩家使用的大语言模型参数。支持 OpenAI、Claude、DeepSeek 等兼容 API。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 模型选择
        _buildSection('模型配置', [_buildModelSelector()]),

        const SizedBox(height: 24),

        // API 配置
        _buildSection('API 配置', [
          _buildBaseUrlInput(),
          const Divider(),
          _buildApiKeyInput(),
        ]),

        const SizedBox(height: 24),

        // 常用配置快捷方式
        _buildSection('快捷配置', [
          _buildPresetTile(
            'OpenAI',
            'gpt-3.5-turbo',
            'https://api.openai.com/v1',
            Icons.public,
          ),
          _buildPresetTile(
            'Claude (Anthropic)',
            'claude-3-5-sonnet-20241022',
            'https://api.anthropic.com/v1',
            Icons.psychology,
          ),
          _buildPresetTile(
            'DeepSeek',
            'deepseek-chat',
            'https://api.deepseek.com/v1',
            Icons.rocket_launch,
          ),
        ]),

        const SizedBox(height: 24),

        // 保存按钮
        FilledButton.icon(
          onPressed: () => _saveConfig(),
          icon: const Icon(Icons.save),
          label: const Text('保存配置'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildModelSelector() {
    return Watch((context) {
      final model = viewModel.llmModel.value;

      return ListTile(
        leading: const Icon(Icons.model_training),
        title: const Text('模型名称'),
        subtitle: Text('当前: $model'),
        trailing: const Icon(Icons.edit),
        onTap: () => _showModelDialog(),
      );
    });
  }

  Widget _buildBaseUrlInput() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _baseUrlController,
        decoration: const InputDecoration(
          labelText: 'Base URL',
          hintText: 'https://api.openai.com/v1',
          prefixIcon: Icon(Icons.link),
          border: OutlineInputBorder(),
          helperText: 'API 服务地址',
        ),
        keyboardType: TextInputType.url,
        onChanged: (value) => viewModel.setLLMBaseUrl(value),
      ),
    );
  }

  Widget _buildApiKeyInput() {
    return Watch((context) {
      final showApiKey = viewModel.showApiKey.value;

      return Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            labelText: 'API Key',
            hintText: 'sk-...',
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              icon: Icon(showApiKey ? Icons.visibility_off : Icons.visibility),
              onPressed: () => viewModel.toggleShowApiKey(),
            ),
            border: const OutlineInputBorder(),
            helperText: 'API 访问密钥',
          ),
          obscureText: !showApiKey,
          onChanged: (value) => viewModel.setLLMApiKey(value),
        ),
      );
    });
  }

  Widget _buildPresetTile(
    String name,
    String model,
    String baseUrl,
    IconData icon,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(name),
      subtitle: Text(model),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        viewModel.setLLMModel(model);
        viewModel.setLLMBaseUrl(baseUrl);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已应用 $name 配置')));
      },
    );
  }

  void _showModelDialog() {
    final TextEditingController controller = TextEditingController(
      text: viewModel.llmModel.value,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置模型名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '模型名称',
            hintText: 'gpt-3.5-turbo',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              viewModel.setLLMModel(controller.text);
              Navigator.of(context).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
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

  void _saveConfig() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('配置已保存'), duration: Duration(seconds: 2)),
    );
  }
}
