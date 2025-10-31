import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/gen/assets.gen.dart';
import 'package:werewolf_arena/page/game/game_view_model.dart';

@RoutePage()
class GamePage extends StatefulWidget {
  const GamePage({super.key, @PathParam('scenarioId') this.scenarioId});

  final String? scenarioId;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final GameViewModel viewModel = GetIt.instance.get<GameViewModel>();
  StreamSubscription? _snackBarSubscription;

  @override
  void initState() {
    super.initState();
    viewModel.initSignals(scenarioId: widget.scenarioId);

    // 设置事件弹窗回调
    viewModel.onShowEventDialog = (message) {
      _showEventDialog(message);
    };

    // 监听SnackBar消息
    _snackBarSubscription = viewModel.snackBarMessages.listen((message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _snackBarSubscription?.cancel();
    viewModel.dispose();
    super.dispose();
  }

  void _showEventDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.event, color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 8),
            Text('游戏事件'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message, style: TextStyle(fontSize: 14, height: 1.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景图
          Assets.background.image(
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
          SafeArea(
            child: Watch((context) {
              final players = viewModel.players.value;
              final isRunning = viewModel.isGameRunning.value;
              final gameStatus = viewModel.gameStatus.value;

              return Column(
                spacing: 16,
                children: [
                  // 顶部信息栏
                  _buildTopBar(context, gameStatus, isRunning),

                  // 玩家展示区域
                  Expanded(child: _buildPlayersArea(context, players)),

                  // 底部操作按钮
                  _buildBottomActions(context, isRunning),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, String status, bool isRunning) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        color: Colors.black.withValues(alpha: 0.5),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.router.maybePop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '狼人杀竞技场',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () => viewModel.navigateSettingsPage(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersArea(BuildContext context, List<dynamic> players) {
    if (players.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.white70),
            SizedBox(height: 16),
            Text(
              '点击开始游戏创建玩家',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        var height = (constraints.maxHeight - 16 * 5) / 6;
        return Column(
          spacing: 16,
          children: [
            for (int row = 0; row < 6; row++)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: row * 2 < players.length
                        ? _buildPlayerInformation(
                            players[row * 2],
                            _AvatarAlignment.start,
                            size: height,
                          )
                        : SizedBox(),
                  ),
                  Expanded(flex: 1, child: SizedBox()),
                  Expanded(
                    flex: 2,
                    child: row * 2 + 1 < players.length
                        ? _buildPlayerInformation(
                            players[row * 2 + 1],
                            _AvatarAlignment.end,
                            size: height,
                          )
                        : SizedBox(),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildPlayerInformation(
    dynamic player,
    _AvatarAlignment alignment, {
    double size = 64,
  }) {
    final isAlive = player.isAlive;
    var radius = Radius.circular(size);
    var borderRadius = BorderRadius.only(
      topRight: alignment == _AvatarAlignment.end ? Radius.zero : radius,
      bottomRight: alignment == _AvatarAlignment.end ? Radius.zero : radius,
      topLeft: alignment == _AvatarAlignment.start ? Radius.zero : radius,
      bottomLeft: alignment == _AvatarAlignment.start ? Radius.zero : radius,
    );
    var startColor = Colors.black.withValues(
      alpha: alignment == _AvatarAlignment.start ? 0 : 0.5,
    );
    var endColor = Colors.black.withValues(
      alpha: alignment == _AvatarAlignment.end ? 0 : 0.5,
    );
    var colors = [startColor, endColor];
    var linearGradient = LinearGradient(
      colors: colors,
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
    );
    var boxDecoration = BoxDecoration(
      borderRadius: borderRadius,
      gradient: linearGradient,
    );

    var avatar = Container(
      decoration: BoxDecoration(
        color: isAlive ? Colors.white : Colors.grey,
        shape: BoxShape.circle,
        border: Border.all(
          color: isAlive ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      height: size - 16,
      width: size - 16,
      child: Center(
        child: Text(
          player.index.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );

    var information = Expanded(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: alignment == _AvatarAlignment.start
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              player.name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Text(
              player.role.name,
              style: TextStyle(color: Colors.white70, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            if (!isAlive) ...[
              SizedBox(height: 2),
              Text(
                '已出局',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    var children = [
      alignment == _AvatarAlignment.start ? information : avatar,
      alignment == _AvatarAlignment.end ? information : avatar,
    ];

    return Container(
      decoration: boxDecoration,
      height: size,
      padding: EdgeInsets.all(8),
      child: Row(spacing: 8, children: children),
    );
  }

  Widget _buildBottomActions(BuildContext context, bool isRunning) {
    final canStart = viewModel.canStartGame.value;

    return Padding(
      padding: EdgeInsets.all(16),
      child: FilledButton.icon(
        onPressed: (canStart && !isRunning) ? viewModel.startGame : null,
        icon: Icon(isRunning ? Icons.hourglass_empty : Icons.play_arrow),
        label: Text(
          isRunning ? '游戏进行中...' : '开始游戏',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
          minimumSize: Size(200, 56),
        ),
      ),
    );
  }
}

enum _AvatarAlignment { start, end }
