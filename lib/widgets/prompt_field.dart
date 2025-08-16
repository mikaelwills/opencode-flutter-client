import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/opencode_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';
import 'cancel_button.dart';

class PromptField extends StatefulWidget {
  final Function(String)? onSendMessage;

  const PromptField({
    super.key,
    this.onSendMessage,
  });

  @override
  State<PromptField> createState() => _PromptFieldState();
}

class _PromptFieldState extends State<PromptField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    // Block sending if already sending a message
    final chatBloc = context.read<ChatBloc>();
    if (chatBloc.state is ChatSendingMessage) {
      return; // Silently block duplicate sends
    }
    
    final message = _controller.text.trim();
    if (message.isNotEmpty && widget.onSendMessage != null) {
      widget.onSendMessage!(message);
      _controller.clear();
    }
  }

  String? _getSessionId(ChatState state) {
    if (state is ChatReady) {
      return state.sessionId;
    } else if (state is ChatSendingMessage) {
      return state.sessionId;
    }
    return null;
  }

  bool _shouldShowCancelButton(ChatState state) {
    final isSendingMessage = state is ChatSendingMessage;
    final isStreamingResponse = state is ChatReady && state.isStreaming;
    return isSendingMessage || isStreamingResponse;
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16),
      height: 56, // Fixed height to prevent growing
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: OpenCodeTheme.primary,
            width: 2,
          ),
          right: BorderSide(
            color: OpenCodeTheme.primary,
            width: 2,
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 12, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Terminal prompt symbol
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                OpenCodeSymbols.prompt,
                style: OpenCodeTextStyles.prompt,
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Input field
          Flexible(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: OpenCodeTextStyles.terminal,
              textAlignVertical: TextAlignVertical.center,
              showCursor: true,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                isDense: false,
                filled: false,
                hintText: 'Type your message...',
                hintStyle: OpenCodeTextStyles.terminal.copyWith(
                  color: OpenCodeTheme.textSecondary.withOpacity(0.6),
                ),
              ),
              maxLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),

          // Cancel button (only during active streaming)
          BlocBuilder<ChatBloc, ChatState>(
            buildWhen: (previous, current) =>
                _shouldShowCancelButton(previous) !=
                _shouldShowCancelButton(current),
            builder: (context, state) {
              final showCancelButton = _shouldShowCancelButton(state);
              final sessionId = _getSessionId(state);

              if (showCancelButton) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 10),
                    CancelButton(sessionId: sessionId ?? ''),
                    const SizedBox(width: 10),
                  ],
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}
