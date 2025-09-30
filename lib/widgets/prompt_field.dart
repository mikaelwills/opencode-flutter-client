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
  final double? initialHeight;
  final EdgeInsetsGeometry? margin;

  const PromptField({
    super.key,
    this.onSendMessage,
    this.onHeightChanged,
    this.initialHeight,
    this.margin,
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHeight());
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _promptKey,
      constraints: const BoxConstraints(
        minHeight: 40,
        maxHeight: 200,
      ),
      margin: widget.margin ?? const EdgeInsets.only(left: 16,top: 16, right: 16),
         
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
            _buildPromptSymbol(),
            const SizedBox(width: 12),
            _buildTextField(),
            _buildActionButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptSymbol() {
    return const Center(
      child: Text(
        OpenCodeSymbols.prompt,
        style: OpenCodeTextStyles.prompt,
      ),
    );
  }

  Widget _buildTextField() {
    final isCompact = widget.initialHeight != null && widget.initialHeight! <= 35;

    return Expanded(
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
          contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 12),
          isDense: false,
          filled: false,
          hintText: 'Type your message...',
          hintStyle: OpenCodeTextStyles.terminal.copyWith(
            color: OpenCodeTheme.textSecondary.withValues(alpha: 0.6),
          ),
        ),
        maxLines: null,
        minLines: 1,
        textInputAction: TextInputAction.newline,
      ),
    );
  }

  Widget _buildActionButton() {
    return BlocBuilder<ChatBloc, ChatState>(
      buildWhen: (previous, current) =>
          _shouldShowCancelButton(previous) != _shouldShowCancelButton(current),
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
    );
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
      final RenderBox? renderBox =
          _promptKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && widget.onHeightChanged != null) {
        widget.onHeightChanged!(renderBox.size.height);
      }
    });
  }

  void _sendMessage() {
    FocusScope.of(context).unfocus();

    final chatBloc = context.read<ChatBloc>();
    if (chatBloc.state is ChatSendingMessage) {
      return;
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
}

