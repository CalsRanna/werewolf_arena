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
      appBar: AppBar(title: Text('Setting')),
      body: Watch((context) {
        final isLoading = viewModel.isLoading.value;
        if (isLoading) return Center(child: CircularProgressIndicator());

        final soundOn = viewModel.soundEnabled.value;
        final animationsOn = viewModel.animationsEnabled.value;
        final theme = viewModel.selectedTheme.value;
        final speed = viewModel.textSpeed.value;
        final logLevel = viewModel.logLevel.value;
        final llmApiKey = viewModel.llmApiKey.value;

        return _buildSettingsContent(
          soundOn,
          animationsOn,
          theme,
          speed,
          logLevel,
          llmApiKey,
        );
      }),
    );
  }

  Widget _buildSettingsContent(
    bool soundOn,
    bool animationsOn,
    String theme,
    double speed,
    String logLevel,
    String llmApiKey,
  ) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'Game',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SwitchListTile(
          value: soundOn,
          onChanged: (value) => viewModel.toggleSound(value),
          title: Text('Sound'),
          subtitle: Text('Enable sound effects'),
        ),
        SwitchListTile(
          value: animationsOn,
          onChanged: (value) => viewModel.toggleAnimations(value),
          title: Text('Animations'),
          subtitle: Text('Enable animations'),
        ),
        ListTile(
          title: Text('Text Speed'),
          subtitle: Text('Adjust text speed'),
          trailing: SizedBox(
            width: 100,
            child: Text(speed.toStringAsFixed(1), textAlign: TextAlign.right),
          ),
        ),
        Slider(
          value: speed,
          onChanged: (value) => viewModel.setTextSpeed(value),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'LLM',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ListTile(
          title: Text('Player Intelligence'),
          subtitle: Text('Configure AI player models'),
          onTap: () => viewModel.navigatePlayerIntelligencePage(context),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'More',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ListTile(
          title: Text('Reset'),
          subtitle: Text('Reset all settings to default'),
          onTap: () => _showResetDialog(),
        ),
      ],
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('设置已重置')));
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
