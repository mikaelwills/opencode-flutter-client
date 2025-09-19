import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/opencode_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';
import 'cancel_button.dart';
import 'send_button.dart';

typedef HeightCallback = void Function(double height);

class PromptField extends StatefulWidget {
  final Function(String)? onSendMessage;
  final HeightCallback? onHeightChanged;

  const PromptField({
    super.key,
    this.onSendMessage,
    this.onHeightChanged,
  });

  @override
  State<PromptField> createState() => _PromptFieldState();
}

class _PromptFieldState extends State<PromptField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _promptKey = GlobalKey();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    // Initial height measurement
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHeight());
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    _updateHeight();
  }

  void _updateHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? renderBox = _promptKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && widget.onHeightChanged != null) {
        widget.onHeightChanged!(renderBox.size.height);
      }
    });
  }

  void _sendMessage() {
    // Dismiss keyboard immediately when send is pressed
    FocusScope.of(context).unfocus();

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
    return Stack(
      children: [
        ConstrainedBox(
          key: _promptKey,
          constraints: const BoxConstraints(
            maxHeight: 200, // Maximum height to prevent excessive growth
          ),
          child: Container(
            margin: const EdgeInsets.only(left: 16, right: 16),
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
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Terminal prompt symbol
          const Center(
            child: Text(
              OpenCodeSymbols.prompt,
              style: OpenCodeTextStyles.prompt,
            ),
          ),
          const SizedBox(width: 12),

          // Input field
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: OpenCodeTextStyles.terminal,
              textAlignVertical: TextAlignVertical.top,
              showCursor: true,
              scrollPhysics: const BouncingScrollPhysics(),
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
              maxLines: null, // Unlimited lines
              minLines: 1, // Start with single line
              textInputAction: TextInputAction.newline,
            ),
          ),

          // Send/Cancel button toggle
          BlocBuilder<ChatBloc, ChatState>(
            buildWhen: (previous, current) =>
                _shouldShowCancelButton(previous) !=
                _shouldShowCancelButton(current),
            builder: (context, state) {
              final showCancelButton = _shouldShowCancelButton(state);
              final sessionId = _getSessionId(state);
              final showSendButton = _hasText && !showCancelButton;

              if (showCancelButton) {
                return Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: CancelButton(sessionId: sessionId ?? ''),
                  ),
                );
              } else if (showSendButton) {
                return Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SendButton(onPressed: _sendMessage),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
            ],
          ),
        ),
      ),
    ),
      ],
    );
  }
}
