import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/opencode_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/chat/chat_state.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_state.dart';
import '../widgets/terminal_message.dart';
import '../widgets/prompt_field.dart';

import '../widgets/connection_status_row.dart';

class ChatScreen extends StatefulWidget {
  final String? sessionId;

  const ChatScreen({
    super.key,
    this.sessionId,
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

    // Get sessionId from SessionBloc or use provided one
    final sessionBloc = context.read<SessionBloc>();
    final sessionState = sessionBloc.state;

    String? sessionId = widget.sessionId;
    if (sessionState is SessionLoaded) {
      sessionId = sessionState.session.id;
    }

    if (sessionId != null && sessionId.isNotEmpty) {
      print('🔍 [ChatScreen] Starting chat with session: $sessionId');
      context.read<ChatBloc>().add(StartChat(sessionId: sessionId));
    } else {
      print('❌ [ChatScreen] No session available');
    }
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

  void _scrollToBottom({bool force = false, bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return; // No content to scroll to

    if (force || _isUserNearBottom) {
      final targetOffset = position.maxScrollExtent;

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
    return Stack(
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
                      if (isNewMessage && isUserMessage) {
                        _scrollToBottom(force: true);
                      } else if (isNewMessage || state.isStreaming) {
                        _scrollToBottom(force: state.isStreaming);
                      }
                    });
                  } else if (state is ChatSendingMessage) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom(force: true);
                    });
                  }
                },
                child: BlocBuilder<ChatBloc, ChatState>(
                  builder: (context, state) {
                    if (state is ChatReady) {
                      final messages = state.messages;
                      final isStreaming = state.isStreaming;

                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            'Type a message to get started',
                            style: OpenCodeTextStyles.terminal,
                          ),
                        );
                      }
                      return ListView.builder(
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

                    if (state is ChatSendingMessage) {
                      final messages = state.messages;

                      if (messages.isEmpty) {
                        return const Center(
                          child: Text(
                            'Type a message to get started',
                            style: OpenCodeTextStyles.terminal,
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];

                          return TerminalMessage(
                            message: message,
                            isStreaming: false, // Not streaming during send
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
                              'Error: ${state.error}',
                              style: const TextStyle(
                                color: OpenCodeTheme.error,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return const Center(
                      child: CircularProgressIndicator(
                        color: OpenCodeTheme.primary,
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
                BlocBuilder<ChatBloc, ChatState>(
                  builder: (context, chatState) {
                    final isEnabled = chatState is ChatReady;
                    final isSending = chatState is ChatSendingMessage;

                    return BlocBuilder<SessionBloc, SessionState>(
                      builder: (context, sessionState) {
                        return PromptField(
                          onSendMessage: isEnabled
                              ? (message) {
                                  context
                                      .read<ChatBloc>()
                                      .add(SendChatMessage(message));
                                }
                              : null,
                          isEnabled: isEnabled && !isSending,
                          placeholder: isSending
                              ? 'Sending message...'
                              : 'Type your message...',
                          sessionId: _getSessionId(),
                        );
                      },
                    );
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
              onPressed: () => _scrollToBottom(force: true),
              backgroundColor: OpenCodeTheme.surface,
              foregroundColor: OpenCodeTheme.primary,
              elevation: 4,
              child: const Icon(Icons.keyboard_arrow_down, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  String _getSessionId() {
    if (widget.sessionId != null && widget.sessionId!.isNotEmpty) {
      return widget.sessionId!;
    }

    final sessionBloc = context.read<SessionBloc>();
    final sessionState = sessionBloc.state;

    if (sessionState is SessionLoaded) {
      return sessionState.session.id;
    }

    return '';
  }
}
