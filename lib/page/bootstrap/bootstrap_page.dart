import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/page/bootstrap/bootstrap_view_model.dart';

@RoutePage()
class BootstrapPage extends StatefulWidget {
  const BootstrapPage({super.key});

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  final BootstrapViewModel viewModel = GetIt.instance.get<BootstrapViewModel>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Watch((context) {
        final isInit = viewModel.isInitialized.value;
        final message = viewModel.initializationMessage.value;
        final progress = viewModel.initializationProgress.value;
        final error = viewModel.errorMessage.value;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo或标题
              Icon(
                Icons.casino,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              Text(
                '狼人杀竞技场',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'AI 对战游戏',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 48),

              // 加载动画或完成图标
              if (!isInit)
                _buildLoadingIndicator(progress)
              else if (error == null)
                Icon(
                  Icons.check_circle,
                  size: 48,
                  color: Colors.green,
                )
              else
                Icon(
                  Icons.error,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
              const SizedBox(height: 16),

              // 初始化消息
              if (error == null)
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                )
              else
                Column(
                  children: [
                    Text(
                      error,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => viewModel.retry(),
                      icon: Icon(Icons.refresh),
                      label: Text('重试'),
                    ),
                  ],
                ),

              // 进度条
              if (!isInit && error == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 16.0),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildLoadingIndicator(double progress) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          Text(
            '${(progress * 100).toInt()}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await viewModel.initSignals();

    if (mounted && viewModel.errorMessage.value == null) {
      // 初始化成功后导航到主页
      viewModel.navigateToHome(context);
    }
  }

  @override
  void dispose() {
    // ViewModel 由 GetIt 管理，不需要在这里 dispose
    super.dispose();
  }
}