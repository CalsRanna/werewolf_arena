import 'package:auto_route/annotations.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:werewolf_arena/gen/assets.gen.dart';
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
      body: Stack(
        children: [
          Assets.background.image(
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
          SafeArea(
            child: Column(
              spacing: 16,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                  height: 64,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      var height = (constraints.maxHeight - 16 * 5) / 6;
                      return Column(
                        spacing: 16,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildPlayerInformation(
                                  _AvatarAlignment.start,
                                  size: height,
                                ),
                              ),
                              Expanded(flex: 1, child: SizedBox()),
                              Expanded(
                                flex: 2,
                                child: _buildPlayerInformation(
                                  _AvatarAlignment.end,
                                  size: height,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildPlayerInformation(
                                  _AvatarAlignment.start,
                                  size: height,
                                ),
                              ),
                              Expanded(flex: 1, child: SizedBox()),
                              Expanded(
                                flex: 2,
                                child: _buildPlayerInformation(
                                  _AvatarAlignment.end,
                                  size: height,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildPlayerInformation(
                                  _AvatarAlignment.start,
                                  size: height,
                                ),
                              ),
                              Expanded(flex: 1, child: SizedBox()),
                              Expanded(
                                flex: 2,
                                child: _buildPlayerInformation(
                                  _AvatarAlignment.end,
                                  size: height,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildPlayerInformation(
                                  _AvatarAlignment.start,
                                  size: height,
                                ),
                              ),
                              Expanded(flex: 1, child: SizedBox()),
                              Expanded(
                                flex: 2,
                                child: _buildPlayerInformation(
                                  _AvatarAlignment.end,
                                  size: height,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildPlayerInformation(
                                  _AvatarAlignment.start,
                                  size: height,
                                ),
                              ),
                              Expanded(flex: 1, child: SizedBox()),
                              Expanded(
                                flex: 2,
                                child: _buildPlayerInformation(
                                  _AvatarAlignment.end,
                                  size: height,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildPlayerInformation(
                                  _AvatarAlignment.start,
                                  size: height,
                                ),
                              ),
                              Expanded(flex: 1, child: SizedBox()),
                              Expanded(
                                flex: 2,
                                child: _buildPlayerInformation(
                                  _AvatarAlignment.end,
                                  size: height,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
                FilledButton(
                  onPressed: viewModel.startGame,
                  child: Text('开始游戏'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerInformation(
    _AvatarAlignment alignment, {
    double size = 64,
  }) {
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
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      height: size - 16,
      width: size - 16,
    );
    var information = Expanded(child: SizedBox());
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
}

enum _AvatarAlignment { start, end }
