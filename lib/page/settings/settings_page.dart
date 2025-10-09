import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/page/settings/settings_view_model.dart';

@RoutePage()
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsViewModel viewModel = GetIt.instance.get<SettingsViewModel>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('设置'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => viewModel.navigateBack(context),
        ),
      ),
      body: Watch((context) {
        // 响应式获取 signals 的值
        final isLoading = viewModel.isLoading.value;
        final soundOn = viewModel.soundEnabled.value;
        final animationsOn = viewModel.animationsEnabled.value;
        final theme = viewModel.selectedTheme.value;
        final speed = viewModel.textSpeed.value;

        // 游戏配置
        final enableColors = viewModel.enableColors.value;
        final showDebugInfo = viewModel.showDebugInfo.value;
        final logLevel = viewModel.logLevel.value;
        final llmApiKey = viewModel.llmApiKey.value;

        if (isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        return _buildSettingsContent(
          soundOn, animationsOn, theme, speed,
          enableColors, showDebugInfo, logLevel, llmApiKey,
        );
      }),
    );
  }

  Widget _buildSettingsContent(
    bool soundOn, bool animationsOn, String theme, double speed,
    bool enableColors, bool showDebugInfo, String logLevel, String llmApiKey,
  ) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // 游戏设置
        _buildSection('游戏设置', [
          _buildSwitchTile(
            '音效',
            '启用游戏音效',
            soundOn,
            (value) => viewModel.toggleSound(value),
          ),
          _buildSwitchTile(
            '动画',
            '启用界面动画',
            animationsOn,
            (value) => viewModel.toggleAnimations(value),
          ),
          _buildSliderTile(
            '文字速度',
            '调整界面文字显示速度',
            speed,
            (value) => viewModel.setTextSpeed(value),
          ),
        ]),

        SizedBox(height: 24),

        // 外观设置
        _buildSection('外观设置', [
          _buildThemeTile(theme),
        ]),

        SizedBox(height: 24),

        // 高级设置
        _buildSection('高级设置', [
          _buildSwitchTile(
            'UI颜色',
            '启用控制台颜色输出',
            enableColors,
            (value) => viewModel.setEnableColors(value),
          ),
          _buildSwitchTile(
            '调试信息',
            '显示详细调试信息',
            showDebugInfo,
            (value) => viewModel.setShowDebugInfo(value),
          ),
          _buildLogLevelTile(logLevel),
        ]),

        SizedBox(height: 24),

        // LLM配置
        _buildSection('AI配置', [
          ListTile(
            leading: Icon(Icons.psychology),
            title: Text('LLM 模型配置'),
            subtitle: Text('配置 AI 玩家使用的语言模型'),
            trailing: Icon(Icons.chevron_right),
            onTap: () => viewModel.navigateToLLMConfig(context),
          ),
        ]),

        SizedBox(height: 24),

        // 关于
        _buildSection('关于', [
          ListTile(
            leading: Icon(Icons.info),
            title: Text('关于应用'),
            subtitle: Text('查看应用信息和版本'),
            onTap: () => viewModel.showAbout(context),
          ),
          ListTile(
            leading: Icon(Icons.description),
            title: Text('许可证'),
            subtitle: Text('查看开源许可证'),
            onTap: () => viewModel.showLicenseDialog(context),
          ),
        ]),

        SizedBox(height: 24),

        // 重置设置
        _buildSection('重置', [
          ListTile(
            leading: Icon(Icons.restore),
            title: Text('重置设置'),
            subtitle: Text('恢复所有设置为默认值'),
            onTap: () => _showResetDialog(),
          ),
        ]),

        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSliderTile(String title, String subtitle, double value, Function(double) onChanged) {
    return Column(
      children: [
        ListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: SizedBox(
            width: 100,
            child: Text(
              value.toStringAsFixed(1),
              textAlign: TextAlign.right,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Slider(
            value: value,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: value.toStringAsFixed(1),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeTile(String theme) {
    return ListTile(
      title: Text('主题'),
      subtitle: Text('选择应用主题'),
      trailing: DropdownButton<String>(
        value: theme,
        items: [
          DropdownMenuItem(value: 'light', child: Text('浅色')),
          DropdownMenuItem(value: 'dark', child: Text('深色')),
          DropdownMenuItem(value: 'system', child: Text('跟随系统')),
        ],
        onChanged: (value) {
          if (value != null) {
            viewModel.setTheme(value);
          }
        },
      ),
    );
  }

  Widget _buildLogLevelTile(String logLevel) {
    return ListTile(
      title: Text('日志级别'),
      subtitle: Text('设置日志记录详细程度'),
      trailing: DropdownButton<String>(
        value: logLevel,
        items: [
          DropdownMenuItem(value: 'debug', child: Text('调试')),
          DropdownMenuItem(value: 'info', child: Text('信息')),
          DropdownMenuItem(value: 'warning', child: Text('警告')),
          DropdownMenuItem(value: 'error', child: Text('错误')),
        ],
        onChanged: (value) {
          if (value != null) {
            viewModel.setLogLevel(value);
          }
        },
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('重置设置'),
        content: Text('确定要重置所有设置为默认值吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              viewModel.resetSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('设置已重置')),
              );
            },
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    viewModel.initSignals();
  }
}