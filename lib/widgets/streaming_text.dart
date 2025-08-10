import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:async';
import '../theme/opencode_theme.dart';

class StreamingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration delay;
  final bool isStreaming;
  final bool useMarkdown;

  const StreamingText({
    super.key,
    required this.text,
    this.style,
    this.delay = const Duration(milliseconds: 20),
    this.isStreaming = true,
    this.useMarkdown = false,
  });

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText> {
  String _displayedText = '';
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isStreaming) {
      _startStreaming();
    } else {
      _displayedText = widget.text;
    }
  }

  @override
  void didUpdateWidget(StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.text != oldWidget.text) {
      _timer?.cancel();
      if (widget.isStreaming) {
        // If text changed and we're streaming, continue from current position
        if (widget.text.startsWith(_displayedText)) {
          _currentIndex = _displayedText.length;
          _startStreaming();
        } else {
          // Text completely changed, restart
          _displayedText = '';
          _currentIndex = 0;
          _startStreaming();
        }
      } else {
        _displayedText = widget.text;
      }
    } else if (widget.isStreaming != oldWidget.isStreaming) {
      if (widget.isStreaming) {
        _startStreaming();
      } else {
        _timer?.cancel();
        _displayedText = widget.text;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startStreaming() {
    if (_currentIndex >= widget.text.length) return;
    
    _timer = Timer.periodic(widget.delay, (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _currentIndex++;
          _displayedText = widget.text.substring(0, _currentIndex);
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useMarkdown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: _displayedText,
            styleSheet: MarkdownStyleSheet(
              p: widget.style ?? OpenCodeTextStyles.terminal,
              code: OpenCodeTextStyles.code,
              codeblockDecoration: BoxDecoration(
                color: OpenCodeTheme.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              codeblockPadding: const EdgeInsets.all(8),
              blockquote: (widget.style ?? OpenCodeTextStyles.terminal).copyWith(
                color: OpenCodeTheme.textSecondary,
              ),
              blockquoteDecoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: OpenCodeTheme.textSecondary,
                    width: 2,
                  ),
                ),
              ),
              h1: (widget.style ?? OpenCodeTextStyles.terminal).copyWith(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              h2: (widget.style ?? OpenCodeTextStyles.terminal).copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              h3: (widget.style ?? OpenCodeTextStyles.terminal).copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              listBullet: widget.style ?? OpenCodeTextStyles.terminal,
              listIndent: 16,
            ),
            selectable: true,
          ),
          if (widget.isStreaming && _currentIndex < widget.text.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '▊',
                style: widget.style?.copyWith(
                  color: widget.style?.color?.withOpacity(0.7),
                ),
              ),
            ),
        ],
      );
    }

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: _displayedText,
            style: widget.style,
          ),
          if (widget.isStreaming && _currentIndex < widget.text.length)
            TextSpan(
              text: '▊',
              style: widget.style?.copyWith(
                color: widget.style?.color?.withOpacity(0.7),
              ),
            ),
        ],
      ),
    );
  }
}