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
  static const double _scrollThreshold = 100.0; // pixels from bottom
  int _lastMessageCount = 0;
  bool _wasStreaming = false;
  double _promptFieldHeight = 60.0; // Default height estimate

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    // Scroll to bottom when entering chat screen (e.g., from sessions list)
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

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final isNearBottom =
        position.pixels >= (position.maxScrollExtent - _scrollThreshold);

    // Only update state if there's a meaningful change
    if (_isUserNearBottom != isNearBottom) {
      setState(() {
        _isUserNearBottom = isNearBottom;
        _showScrollToBottomButton =
            !isNearBottom && position.maxScrollExtent > 0;
      });
    }
  }

  double _calculateMessageHeight(OpenCodeMessage? message) {
    if (message == null) return 100; // Safe fallback

    // Get total character count from all text parts
    final totalChars = message.parts
        .where((part) => part.type == 'text')
        .map((part) => part.content?.length ?? 0)
        .fold(0, (sum, length) => sum + length);

    // Simple estimation: 1.5 pixels per character (includes wrapping)
    // Plus base message padding (32px)
    final calculatedHeight = (totalChars * 1.1);

    return calculatedHeight;
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
    if (position.maxScrollExtent <= 0) return; // No content to scroll to

    if (force || _isUserNearBottom) {
      // Use post-frame callback to ensure ListView has updated its dimensions
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionBloc, SessionState>(
      listener: (context, state) {
        // If the session is no longer valid (e.g., error, not found),
        // redirect the user to the connect screen.
        if (state is SessionError || state is SessionNotFound) {
          // Use go router to navigate, ensuring the user can't go back to a broken chat screen.
          context.go('/connect');
        }
      },
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: BlocListener<ChatBloc, ChatState>(
                  listener: (context, state) {
                    if (state is ChatReady) {
                      final currentMessageCount = state.messages.length;
                      final isNewMessage =
                          currentMessageCount > _lastMessageCount;
                      final isUserMessage = state.messages.isNotEmpty &&
                          state.messages.last.role == 'user';

                      _lastMessageCount = currentMessageCount;

                      // Check if streaming just stopped
                      final streamingJustStopped =
                          _wasStreaming && !state.isStreaming;
                      _wasStreaming = state.isStreaming;

                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final lastMessage = state.messages.isNotEmpty
                            ? state.messages.last
                            : null;
                        if (isNewMessage && isUserMessage) {
                          // Immediate scroll for user messages
                          _scrollToBottom(
                              force: true, lastMessage: lastMessage);
                        } else if (isNewMessage && !state.isStreaming) {
                          // Immediate scroll when streaming completes
                          _scrollToBottom(
                              force: true, lastMessage: lastMessage);
                        } else if (streamingJustStopped) {
                          // Fallback scroll when streaming just stopped
                          print(
                              '🎯 [ChatScreen] Streaming stopped - final scroll to bottom');
                          _scrollToBottom(
                              force: true, lastMessage: lastMessage);
                        } else if (state.isStreaming) {
                          // Immediate scroll during streaming for live effect
                          _scrollToBottom(
                              force: true, lastMessage: lastMessage);
                        } else if (state.isReconnectionRefresh &&
                            _isUserNearBottom) {
                          // User was at bottom before reconnection, scroll back to bottom
                          print(
                              '🔄 [ChatScreen] Reconnection detected - restoring bottom scroll position');
                          _scrollToBottom(
                              force: true, lastMessage: lastMessage);
                        }
                      });
                    } else if (state is ChatSendingMessage) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final lastMessage = state.messages.isNotEmpty
                            ? state.messages.last
                            : null;
                        _scrollToBottom(force: true, lastMessage: lastMessage);
                      });
                    }
                  },
                  child: BlocBuilder<ChatBloc, ChatState>(
                    builder: (context, state) {
                      if (state is ChatReady || state is ChatSendingMessage) {
                        final messages = state is ChatReady
                            ? state.messages
                            : (state as ChatSendingMessage).messages;
                        final isStreaming =
                            state is ChatReady ? state.isStreaming : false;

                        if (messages.isEmpty) {
                          return const Center(
                            child: Text(
                              'Type a message to get started',
                              style: OpenCodeTextStyles.terminal,
                            ),
                          );
                        }

                        return ListView.builder(
                          key: const ValueKey(
                              'message-list'), // Preserve widget identity
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isLastMessage = index == messages.length - 1;
                            final isStreamingMessage =
                                isStreaming && isLastMessage;

                            return TerminalMessage(
                              message: message,
                              isStreaming: isStreamingMessage,
                            );
                          },
                        );
                      }

                      if (state is ChatError) {
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
                                  context
                                      .read<ChatBloc>()
                                      .add(LoadMessagesForCurrentSession());
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      // Show empty state instead of loading indicator
                      return const Center(
                        child: Text(
                          'Connecting to chat...',
                          style: TextStyle(color: OpenCodeTheme.textSecondary),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Input area
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PromptField(
                    onSendMessage: (message) {
                      context.read<ChatBloc>().add(SendChatMessage(message));
                    },
                    onHeightChanged: _onPromptFieldHeightChanged,
                  ),
                  const ConnectionStatusRow(),
                ],
              ),
            ],
          ),

          // Scroll-to-bottom button positioned above prompt field
          if (_showScrollToBottomButton)
            Positioned(
              bottom: _promptFieldHeight +
                  60, // 40px above prompt field (includes ConnectionStatusRow)
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
            ),
        ],
      ),
    );
  }
}
