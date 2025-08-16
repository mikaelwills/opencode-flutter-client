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
    return (totalChars * 1.5) + 32;
  }

  void _scrollToBottom({bool force = false, bool animate = true, OpenCodeMessage? lastMessage}) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return; // No content to scroll to

    if (force || _isUserNearBottom) {
      // Add extra scroll distance based on last message height
      final extraHeight = _calculateMessageHeight(lastMessage);
      final targetOffset = position.maxScrollExtent + extraHeight;

      if (animate && (targetOffset - position.pixels).abs() > 10) {
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(targetOffset);
      }
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
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final lastMessage = state.messages.isNotEmpty ? state.messages.last : null;
                      if (isNewMessage && isUserMessage) {
                        _scrollToBottom(force: true, lastMessage: lastMessage);
                      } else if (isNewMessage || state.isStreaming) {
                        _scrollToBottom(force: state.isStreaming, lastMessage: lastMessage);
                      } else if (state.isReconnectionRefresh && _isUserNearBottom) {
                        // User was at bottom before reconnection, scroll back to bottom
                        print('🔄 [ChatScreen] Reconnection detected - restoring bottom scroll position');
                        _scrollToBottom(force: true, lastMessage: lastMessage);
                      }
                    });
                  } else if (state is ChatSendingMessage) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final lastMessage = state.messages.isNotEmpty ? state.messages.last : null;
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
                        key: const ValueKey('message-list'), // Preserve widget identity
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
                                context.read<ChatBloc>().add(LoadMessagesForCurrentSession());
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
                ),
                const ConnectionStatusRow(),
              ],
            ),
          ],
        ),
        // Scroll to bottom button
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          bottom: _showScrollToBottomButton ? 80 : -60, // Above the input area
          right: 16,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _showScrollToBottomButton ? 1.0 : 0.0,
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
              backgroundColor: OpenCodeTheme.surface,
              foregroundColor: OpenCodeTheme.primary,
              elevation: 4,
              child: const Icon(Icons.keyboard_arrow_down, size: 20),
            ),
          ),
        ),
        ],
      ),
    );
  }
}
