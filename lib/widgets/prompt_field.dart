import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/opencode_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';
import 'cancel_button.dart';

class PromptField extends StatefulWidget {
  final Function(String)? onSendMessage;
  final bool isEnabled;
  final String placeholder;

  const PromptField({
    super.key,
    this.onSendMessage,
    this.isEnabled = true,
    this.placeholder = 'Type your message...',
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

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        // Show cancel button when working (same logic as "Working..." indicator)
        final isSendingMessage = state is ChatSendingMessage;
        final isStreamingResponse = state is ChatReady && state.isStreaming;
        final isWorking = isSendingMessage || isStreamingResponse;
        final stateSessionId = _getSessionId(state);
        
        
        // Show cancel button when working
        final showCancelButton = isWorking;

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
              const Text(
                OpenCodeSymbols.prompt,
                style: OpenCodeTextStyles.prompt,
              ),
              const SizedBox(width: 12),

              // Input field
              Flexible(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.isEnabled,
                  style: OpenCodeTextStyles.terminal,
                  textAlignVertical: TextAlignVertical.center,
                           showCursor: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                    isDense: false,
                    filled: false,
                  ),
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: widget.isEnabled ? (_) => _sendMessage() : null,
                ),
              ),

              // Cancel button (only during active streaming)
              if (showCancelButton) ...[
                const SizedBox(width: 10),
                CancelButton(sessionId: stateSessionId ?? ''),
                const SizedBox(width: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

