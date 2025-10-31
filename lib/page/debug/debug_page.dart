import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';
import 'package:werewolf_arena/page/debug/debug_view_model.dart';

@RoutePage()
class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final viewModel = GetIt.instance.get<DebugViewModel>();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEBUG'),
        actions: [
          IconButton(
            onPressed: () {
              viewModel.navigateSettingsPage(context);
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Watch((_) => _buildBody(viewModel.logs.value)),
      floatingActionButton: Watch((_) {
        if (viewModel.running.value) {
          return FloatingActionButton(
            onPressed: () => viewModel.stopGame(),
            child: const Icon(Icons.stop),
          );
        }
        return FloatingActionButton(
          onPressed: () => viewModel.startGame(),
          child: const Icon(Icons.play_arrow),
        );
      }),
    );
  }

  Widget _buildBody(List<String> logs) {
    return ListView.builder(
      itemBuilder: (context, index) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary,
              ),
              height: 8,
              margin: EdgeInsets.only(top: 8),
              width: 8,
            ),
            Expanded(child: Text(logs[index])),
          ],
        );
      },
      itemCount: logs.length,
      padding: EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
