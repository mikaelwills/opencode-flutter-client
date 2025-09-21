import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../theme/opencode_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/chat/chat_state.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_state.dart';
import '../widgets/terminal_message.dart';
import '../widgets/prompt_field.dart';
import '../widgets/connection_status_row.dart';
import '../widgets/mode_toggle_button.dart';
import '../models/opencode_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ScrollController _scrollController;
  bool _isUserNearBottom = true;
  bool _showScrollToBottomButton = false;
  static const double _scrollThreshold = 100.0;
  int _lastMessageCount = 0;
  bool _wasStreaming = false;
  double _promptFieldHeight = 60.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatBloc = context.read<ChatBloc>();
      final lastMessage = chatBloc.state is ChatReady
          ? (chatBloc.state as ChatReady).messages.isNotEmpty
              ? (chatBloc.state as ChatReady).messages.last
              : null
          : null;
      _scrollToBottom(force: true, lastMessage: lastMessage);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionBloc, SessionState>(
      listener: (context, state) {
        if (state is SessionError || state is SessionNotFound) {
          context.go('/connect');
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              const ConnectionStatusRow(),
              Expanded(child: _buildChatArea()),
              _buildInputArea(),
            ],
          ),
          if (_showScrollToBottomButton) _buildScrollToBottomButton(),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return BlocListener<ChatBloc, ChatState>(
      listener: _handleChatStateChange,
      child: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) {
          if (state is ChatReady || state is ChatSendingMessage) {
            return _buildMessagesList(state);
          }
          if (state is ChatError) {
            return _buildErrorState(state);
          }
          return _buildConnectingState();
        },
      ),
    );
  }

  Widget _buildMessagesList(ChatState state) {
    final messages = state is ChatReady
        ? state.messages
        : (state as ChatSendingMessage).messages;
    final isStreaming = state is ChatReady ? state.isStreaming : false;

    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'Type a message to get started',
          style: OpenCodeTextStyles.terminal,
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey('message-list'),
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isLastMessage = index == messages.length - 1;
        final isStreamingMessage = isStreaming && isLastMessage;

        return TerminalMessage(
          message: message,
          isStreaming: isStreamingMessage,
        );
      },
    );
  }

  Widget _buildErrorState(ChatError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: OpenCodeTheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            state.error,
            style: const TextStyle(
              color: OpenCodeTheme.error,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<ChatBloc>().add(LoadMessagesForCurrentSession());
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingState() {
    return const Center(
      child: Text(
        'Connecting to chat...',
        style: TextStyle(color: OpenCodeTheme.textSecondary),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: PromptField(
              margin: EdgeInsets.zero,
              initialHeight: 30,
              onSendMessage: (message) {
                context.read<ChatBloc>().add(SendChatMessage(message));
              },
              onHeightChanged: _onPromptFieldHeightChanged,
            ),
          ),
          const SizedBox(width: 8),
          const ModeToggleButton(isInNotes: false),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    return Positioned(
      bottom: _promptFieldHeight + 40,
      right: 30,
      child: FloatingActionButton.small(
        onPressed: () {
          final chatBloc = context.read<ChatBloc>();
          final lastMessage = chatBloc.state is ChatReady
              ? (chatBloc.state as ChatReady).messages.isNotEmpty
                  ? (chatBloc.state as ChatReady).messages.last
                  : null
              : null;
          _scrollToBottom(force: true, lastMessage: lastMessage);
        },
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        child: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }

  void _handleChatStateChange(BuildContext context, ChatState state) {
    if (state is ChatReady) {
      final currentMessageCount = state.messages.length;
      final isNewMessage = currentMessageCount > _lastMessageCount;
      final isUserMessage =
          state.messages.isNotEmpty && state.messages.last.role == 'user';

      _lastMessageCount = currentMessageCount;

      final streamingJustStopped = _wasStreaming && !state.isStreaming;
      _wasStreaming = state.isStreaming;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final lastMessage =
            state.messages.isNotEmpty ? state.messages.last : null;
        if (isNewMessage && isUserMessage) {
          _scrollToBottom(force: true, lastMessage: lastMessage);
        } else if (isNewMessage && !state.isStreaming) {
          _scrollToBottom(force: true, lastMessage: lastMessage);
        } else if (streamingJustStopped) {
          print('🎯 [ChatScreen] Streaming stopped - final scroll to bottom');
          _scrollToBottom(force: true, lastMessage: lastMessage);
        } else if (state.isStreaming) {
          _scrollToBottom(force: true, lastMessage: lastMessage);
        } else if (state.isReconnectionRefresh && _isUserNearBottom) {
          print(
              '🔄 [ChatScreen] Reconnection detected - restoring bottom scroll position');
          _scrollToBottom(force: true, lastMessage: lastMessage);
        }
      });
    } else if (state is ChatSendingMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final lastMessage =
            state.messages.isNotEmpty ? state.messages.last : null;
        _scrollToBottom(force: true, lastMessage: lastMessage);
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final isNearBottom =
        position.pixels >= (position.maxScrollExtent - _scrollThreshold);

    if (_isUserNearBottom != isNearBottom) {
      setState(() {
        _isUserNearBottom = isNearBottom;
        _showScrollToBottomButton =
            !isNearBottom && position.maxScrollExtent > 0;
      });
    }
  }

  void _onPromptFieldHeightChanged(double height) {
    setState(() {
      _promptFieldHeight = height;
    });
  }

  void _scrollToBottom(
      {bool force = false, bool animate = true, OpenCodeMessage? lastMessage}) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    if (force || _isUserNearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;

        final updatedPosition = _scrollController.position;
        final targetOffset = updatedPosition.maxScrollExtent;

        if (animate && (targetOffset - updatedPosition.pixels).abs() > 10) {
          _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(targetOffset);
        }
      });
    }
  }
}
