import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:werewolf_arena/page/home/home_view_model.dart';

@RoutePage()
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = GetIt.instance.get<HomeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('狼人杀竞技场'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => viewModel.navigateToSettings(context),
            tooltip: '设置',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 欢迎区域
              _buildWelcomeSection(context),
              const SizedBox(height: 32),

              // 主要操作按钮
              _buildMainActions(context, viewModel),
              const SizedBox(height: 32),

              // 其他功能
              _buildOtherFeatures(viewModel),
              const Spacer(),

              // 底部信息
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.casino,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          '欢迎来到狼人杀竞技场',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '与AI玩家一起体验经典的狼人杀游戏',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildMainActions(BuildContext context, HomeViewModel viewModel) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => viewModel.startNewGame(context),
            icon: Icon(Icons.play_arrow),
            label: Text(
              '开始新游戏',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: () => viewModel.showGameRules(context),
            icon: Icon(Icons.help_outline),
            label: Text(
              '游戏规则',
              style: TextStyle(fontSize: 16),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherFeatures(HomeViewModel viewModel) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.history),
            title: Text('游戏历史'),
            subtitle: Text('查看之前的游戏记录'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 实现游戏历史功能
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.leaderboard),
            title: Text('排行榜'),
            subtitle: Text('查看AI玩家的胜率统计'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 实现排行榜功能
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.science),
            title: Text('游戏实验室'),
            subtitle: Text('测试不同角色配置的游戏'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 实现游戏实验室功能
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Center(
      child: Text(
        '版本 2.0.0 - Flutter架构',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
        ),
      ),
    );
  }
}