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
        final scenarios = viewModel.scenarios.value;

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
                SizedBox(height: 24),

                // 场景列表
                Expanded(child: _buildScenarioList(context, scenarios)),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.casino,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择游戏场景',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '选择一个场景开始AI狼人杀游戏',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScenarioList(BuildContext context, List<dynamic> scenarios) {
    if (scenarios.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('暂无可用场景', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.getGridCrossAxisCount(
          context,
          mobile: 1,
          tablet: 2,
          desktop: 3,
        ),
        childAspectRatio: Responsive.getGridChildAspectRatio(
          context,
          mobile: 1.5,
          tablet: 1.5,
          desktop: 1.3,
        ),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: scenarios.length,
      itemBuilder: (context, index) {
        final scenario = scenarios[index];
        return _buildScenarioCard(context, scenario);
      },
    );
  }

  Widget _buildScenarioCard(BuildContext context, dynamic scenario) {
    return Card(
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => viewModel.startScenario(context, scenario),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.groups,
                      size: 32,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.info_outline),
                    onPressed: () =>
                        viewModel.showScenarioRules(context, scenario),
                    tooltip: '查看规则',
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                scenario.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                scenario.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => viewModel.startScenario(context, scenario),
                  icon: Icon(Icons.play_arrow),
                  label: Text('开始游戏'),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
