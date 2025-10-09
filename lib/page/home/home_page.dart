import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/page/home/home_view_model.dart';
import 'package:werewolf_arena/util/responsive.dart';

@RoutePage()
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeViewModel viewModel = GetIt.instance.get<HomeViewModel>();

  @override
  void initState() {
    super.initState();
    viewModel.initSignals();
  }

  @override
  Widget build(BuildContext context) {
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
      body: Watch((context) {
        final isLoading = viewModel.isLoading.value;
        final scenarioName = viewModel.currentScenarioName.value;
        final scenarioCount = viewModel.availableScenarioCount.value;

        if (isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        return SafeArea(
          child: ResponsiveWrapper(
            applyCenterConstraint: true,
            applyPadding: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 欢迎区域
                _buildWelcomeSection(context),
                SizedBox(height: Responsive.responsiveValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0)),

                // 当前场景信息
                _buildScenarioInfo(context, scenarioName, scenarioCount),
                SizedBox(height: Responsive.responsiveValue(context, mobile: 16.0, tablet: 20.0, desktop: 24.0)),

                // 主要操作按钮
                _buildMainActions(context, viewModel),
                SizedBox(height: Responsive.responsiveValue(context, mobile: 20.0, tablet: 28.0, desktop: 32.0)),

                // 其他功能
                _buildOtherFeatures(viewModel),
                const Spacer(),

                // 底部信息
                _buildFooter(context),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    final iconSize = Responsive.getResponsiveIconSize(context, mobile: 40.0, tablet: 44.0, desktop: 48.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.casino,
          size: iconSize,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(height: Responsive.responsiveValue(context, mobile: 12.0, desktop: 16.0)),
        Text(
          '欢迎来到狼人杀竞技场',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: Responsive.getResponsiveFontSize(context, mobile: 24.0, tablet: 28.0, desktop: 32.0),
          ),
        ),
        SizedBox(height: Responsive.responsiveValue(context, mobile: 6.0, desktop: 8.0)),
        Text(
          '与AI玩家一起体验经典的狼人杀游戏',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: Responsive.getResponsiveFontSize(context, mobile: 14.0, tablet: 15.0, desktop: 16.0),
          ),
        ),
      ],
    );
  }

  Widget _buildScenarioInfo(BuildContext context, String scenarioName, int scenarioCount) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '当前场景',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => viewModel.showScenarioSelection(context),
                  icon: Icon(Icons.edit, size: 16),
                  label: Text('切换'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              scenarioName.isNotEmpty ? scenarioName : '未选择',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '可用场景: $scenarioCount 个',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainActions(BuildContext context, HomeViewModel viewModel) {
    final buttonHeight = Responsive.responsiveValue(context, mobile: 52.0, tablet: 54.0, desktop: 56.0);
    final buttonFontSize = Responsive.getResponsiveFontSize(context, mobile: 16.0, tablet: 17.0, desktop: 18.0);

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: ElevatedButton.icon(
            onPressed: () => viewModel.startNewGame(context),
            icon: Icon(Icons.play_arrow),
            label: Text(
              '开始新游戏',
              style: TextStyle(fontSize: buttonFontSize, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        SizedBox(height: Responsive.responsiveValue(context, mobile: 10.0, desktop: 12.0)),
        SizedBox(
          width: double.infinity,
          height: buttonHeight,
          child: OutlinedButton.icon(
            onPressed: () => viewModel.showGameRules(context),
            icon: Icon(Icons.help_outline),
            label: Text(
              '游戏规则',
              style: TextStyle(fontSize: buttonFontSize - 2),
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
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}