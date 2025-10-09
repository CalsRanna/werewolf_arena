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
    final isRunning = viewModel.isGameRunning.value;
    final isPaused = viewModel.isPaused.value;

    return Row(
      children: [
        // 左侧控制面板
        Container(
          width: 280,
          child: Card(
            margin: EdgeInsets.all(16),
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.control_camera, color: Theme.of(context).colorScheme.primary),
                      SizedBox(width: 8),
                      Text(
                        '游戏控制',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 24),

                  // 游戏状态显示
                  _buildGameStatus(),

                  SizedBox(height: 24),

                  // 控制按钮
                  _buildControlButtons(),

                  SizedBox(height: 24),

                  // 游戏速度控制
                  _buildSpeedControl(),

                  Spacer(),

                  // 底部提示
                  if (!isRunning)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '点击开始游戏按钮启动AI对战',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // 中间游戏区域
        Expanded(
          flex: 2,
          child: Card(
            margin: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, color: Theme.of(context).colorScheme.primary),
                          SizedBox(width: 8),
                          Text(
                            viewModel.formattedTime.value,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (isPaused)
                        Chip(
                          avatar: Icon(Icons.pause_circle, size: 16),
                          label: Text('已暂停'),
                          backgroundColor: Colors.orange.withValues(alpha: 0.2),
                        ),
                    ],
                  ),
                  Divider(height: 24),

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
        Container(
          width: 320,
          child: Card(
            margin: EdgeInsets.all(16),
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                      SizedBox(width: 8),
                      Text(
                        '事件日志',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Divider(height: 24),

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
    final status = viewModel.gameStatus.value;
    final aliveCount = viewModel.alivePlayersCount.value;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusRow(Icons.info, '状态', status),
          SizedBox(height: 8),
          _buildStatusRow(Icons.favorite, '存活玩家', '$aliveCount 人'),
          SizedBox(height: 8),
          _buildStatusRow(Icons.calendar_today, '当前天数', '${viewModel.currentDay.value} 天'),
        ],
      ),
    );
  }

  Widget _buildStatusRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlButtons() {
    final canStart = viewModel.canStartGame.value;
    final canPause = viewModel.canPauseGame.value;
    final canResume = viewModel.canResumeGame.value;
    final isRunning = viewModel.isGameRunning.value;
    final isPaused = viewModel.isPaused.value;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: canStart ? () => viewModel.startGame() : null,
            icon: Icon(Icons.play_arrow),
            label: Text('开始游戏', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),

        SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: (canPause || canResume)
                      ? () => isPaused ? viewModel.resumeGame() : viewModel.pauseGame()
                      : null,
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 18),
                  label: Text(isPaused ? '恢复' : '暂停'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  onPressed: isRunning ? () => viewModel.resetGame() : null,
                  icon: Icon(Icons.refresh, size: 18),
                  label: Text('重置'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedControl() {
    final speed = viewModel.gameSpeed.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.speed, size: 16, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 8),
            Text(
              '游戏速度',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Spacer(),
            Text(
              '${speed.toStringAsFixed(1)}x',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Slider(
          value: speed,
          min: 0.5,
          max: 5.0,
          divisions: 9,
          label: '${speed.toStringAsFixed(1)}x',
          onChanged: (value) => viewModel.setGameSpeed(value),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0.5x', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('5.0x', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildPlayersGrid() {
    final players = viewModel.players.value;

    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              '暂无玩家',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 8),
            Text(
              '点击开始游戏创建AI玩家',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1.6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        return _buildPlayerCard(player);
      },
    );
  }

  Widget _buildPlayerCard(player) {
    final isAlive = player.isAlive;

    return Card(
      elevation: isAlive ? 2 : 0,
      color: isAlive
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAlive
                ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)
                : Colors.transparent,
            width: 1,
          ),
        ),
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 玩家头像
            CircleAvatar(
              radius: 20,
              backgroundColor: isAlive
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.grey[300],
              child: Icon(
                isAlive ? Icons.person : Icons.person_off,
                color: isAlive
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Colors.grey[600],
                size: 20,
              ),
            ),
            SizedBox(height: 8),

            // 玩家名称
            Text(
              player.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isAlive ? null : Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: 4),

            // 角色
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isAlive
                    ? Theme.of(context).colorScheme.secondaryContainer
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                player.role.name,
                style: TextStyle(
                  fontSize: 10,
                  color: isAlive
                      ? Theme.of(context).colorScheme.onSecondaryContainer
                      : Colors.grey[600],
                ),
              ),
            ),

            // 出局标记
            if (!isAlive) ...[
              SizedBox(height: 4),
              Text(
                '已出局',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventLog() {
    final events = viewModel.eventLog.value;

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message_outlined, size: 48, color: Colors.grey[400]),
            SizedBox(height: 12),
            Text(
              '暂无事件',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 4),
            Text(
              '游戏事件将在此显示',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        reverse: true,
        padding: EdgeInsets.all(12),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[events.length - 1 - index];
          return Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(right: 8, top: 4),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    event,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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