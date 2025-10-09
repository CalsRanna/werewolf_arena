import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/page/game/game_view_model.dart';

@RoutePage()
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final GameViewModel viewModel = GetIt.instance.get<GameViewModel>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('狼人杀竞技场'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => viewModel.navigateSettingsPage(context),
            tooltip: '设置',
          ),
        ],
      ),
      body: Watch((context) {
        return _buildGameContent();
      }),
    );
  }

  Widget _buildGameContent() {
    return Row(
      children: [
        // 左侧控制面板
        Expanded(
          flex: 1,
          child: Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '游戏控制',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),

                  // 游戏状态显示
                  _buildGameStatus(),

                  SizedBox(height: 16),

                  // 控制按钮
                  _buildControlButtons(),

                  SizedBox(height: 16),

                  // 游戏速度控制
                  _buildSpeedControl(),
                ],
              ),
            ),
          ),
        ),

        // 中间游戏区域
        Expanded(
          flex: 2,
          child: Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viewModel.formattedTime.value,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),

                  // 玩家列表
                  Expanded(
                    child: _buildPlayersGrid(),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 右侧事件日志
        Expanded(
          flex: 1,
          child: Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '事件日志',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),

                  Expanded(
                    child: _buildEventLog(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('状态: ${viewModel.gameStatus.value}'),
        Text('存活: ${viewModel.alivePlayersCount.value}'),
        if (viewModel.isPaused.value)
          Text(
            '已暂停',
            style: TextStyle(color: Colors.orange),
          ),
      ],
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: viewModel.canStartGame.value
                ? () => viewModel.startGame()
                : null,
            child: Text('开始游戏'),
          ),
        ),

        SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: (viewModel.canPauseGame.value || viewModel.canResumeGame.value)
                    ? () => viewModel.isPaused.value ? viewModel.resumeGame() : viewModel.pauseGame()
                    : null,
                child: Text(viewModel.isPaused.value ? '恢复' : '暂停'),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: viewModel.isGameRunning.value
                    ? () => viewModel.resetGame()
                    : null,
                child: Text('重置'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('游戏速度: ${viewModel.gameSpeed.value.toStringAsFixed(1)}x'),
        Slider(
          value: viewModel.gameSpeed.value,
          min: 0.5,
          max: 5.0,
          divisions: 9,
          onChanged: (value) => viewModel.setGameSpeed(value),
        ),
      ],
    );
  }

  Widget _buildPlayersGrid() {
    final players = viewModel.players.value;

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        return Card(
          color: player.isAlive
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.error.withOpacity(0.2),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  player.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: player.isAlive ? null : Colors.grey,
                  ),
                ),
                Text(
                  player.role.name,
                  style: TextStyle(
                    fontSize: 12,
                    color: player.isAlive ? null : Colors.grey,
                  ),
                ),
                if (!player.isAlive)
                  Text(
                    '已出局',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEventLog() {
    final events = viewModel.eventLog.value;

    return ListView.builder(
      reverse: true,
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[events.length - 1 - index];
        return Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Text(
            event,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    viewModel.initSignals();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }
}