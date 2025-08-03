import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:opencode_flutter_client/blocs/chat/chat_bloc.dart';
import 'package:opencode_flutter_client/blocs/chat/chat_state.dart';
import '../theme/opencode_theme.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_state.dart' as connection_states;
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';

class ConnectionStatusRow extends StatefulWidget {
  const ConnectionStatusRow({super.key});

  @override
  State<ConnectionStatusRow> createState() => _ConnectionStatusRowState();
}

class _ConnectionStatusRowState extends State<ConnectionStatusRow>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigCubit, ConfigState>(
      builder: (context, configState) {
        final connectionBloc = context.read<ConnectionBloc>();
        final openCodeClient = connectionBloc.openCodeClient;
        final modelName = openCodeClient.modelDisplayName;

        return BlocBuilder<ConnectionBloc, connection_states.ConnectionState>(
          builder: (context, connectionState) {
            String ipText = '...';
            if (configState is ConfigLoaded) {
              ipText = configState.serverIp;
            }

            String statusText;
            if (connectionState is connection_states.ConnectedWithSession) {
              statusText = 'Connected to $ipText';
            } else if (connectionState is connection_states.Reconnecting) {
              statusText = 'Reconnecting to $ipText...';
            } else {
              statusText = 'Disconnected from $ipText';
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  BlocBuilder<ChatBloc, ChatState>(
                      builder: (context, chatState) {
                    // Check if we're working: either sending a message OR streaming a response
                    final isSendingMessage = chatState is ChatSendingMessage;
                    final isStreamingResponse =
                        chatState is ChatReady && chatState.isStreaming;
                    final isWorking = isSendingMessage || isStreamingResponse;
                    final displayText = modelName;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          displayText,
                          style: OpenCodeTextStyles.terminal.copyWith(
                            fontSize: 11,
                            color: OpenCodeTheme.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        if (isWorking) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 70,
                            child: AnimatedDots(
                              textStyle: OpenCodeTextStyles.terminal.copyWith(
                                fontSize: 11,
                                color: OpenCodeTheme.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        statusText,
                        style: const TextStyle(
                          color: OpenCodeTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      _buildConnectionIndicator(connectionState)
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildConnectionIndicator(connection_states.ConnectionState state) {
    Color color;
    bool shouldPulse = false;

    if (state is connection_states.ConnectedWithSession) {
      color = OpenCodeTheme.success;
      shouldPulse = true;
    } else if (state is connection_states.Reconnecting) {
      color = OpenCodeTheme.warning;
    } else {
      color = OpenCodeTheme.error;
    }

    Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );

    if (shouldPulse) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: dot,
          );
        },
      );
    }

    return dot;
  }
}

class AnimatedDots extends StatefulWidget {
  final TextStyle textStyle;

  const AnimatedDots({super.key, required this.textStyle});

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = IntTween(begin: 0, end: 3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final dotCount = _animation.value;
        final dots = '.' * dotCount;
        return Text(
          'working$dots',
          style: widget.textStyle,
        );
      },
    );
  }
}
