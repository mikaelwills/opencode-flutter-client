import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:async';
import '../theme/opencode_theme.dart';
import '../utils/text_sanitizer.dart';

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
  String _sanitizedFullText = '';
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Sanitize the full text once at initialization
    _sanitizedFullText = _safeTextSanitize(widget.text, preserveMarkdown: widget.useMarkdown);
    
    if (widget.isStreaming) {
      _startStreaming();
    } else {
      _displayedText = _sanitizedFullText;
    }
  }

  @override
  void didUpdateWidget(StreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.text != oldWidget.text) {
      // Re-sanitize the full text when it changes
      _sanitizedFullText = _safeTextSanitize(widget.text, preserveMarkdown: widget.useMarkdown);
      
      _timer?.cancel();
      if (widget.isStreaming) {
        // If text changed and we're streaming, continue from current position
        if (_sanitizedFullText.startsWith(_displayedText)) {
          _currentIndex = _displayedText.length;
          _startStreaming();
        } else {
          // Text completely changed, restart streaming
          _currentIndex = 0;
          _displayedText = '';
          _startStreaming();
        }
      } else {
        _displayedText = _sanitizedFullText;
      }
    } else if (widget.isStreaming != oldWidget.isStreaming) {
      if (widget.isStreaming) {
        _startStreaming();
      } else {
        _timer?.cancel();
        _displayedText = _sanitizedFullText;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startStreaming() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.delay, (timer) {
      if (_currentIndex < _sanitizedFullText.length) {
        setState(() {
          _currentIndex++;
          // Use the pre-sanitized text, just substring it
          _displayedText = _sanitizedFullText.substring(0, _currentIndex);
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
          if (widget.isStreaming && _currentIndex < _sanitizedFullText.length)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '▊',
                style: widget.style?.copyWith(
                  color: widget.style?.color?.withValues(alpha: 0.7),
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
            text: _displayedText, // Already sanitized, no need to sanitize again
            style: widget.style,
          ),
          if (widget.isStreaming && _currentIndex < _sanitizedFullText.length)
            TextSpan(
              text: '▊',
              style: widget.style?.copyWith(
                color: widget.style?.color?.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  /// Safe text sanitization with fallback handling
  String _safeTextSanitize(String text, {bool preserveMarkdown = true}) {
    try {
      return TextSanitizer.sanitize(text, preserveMarkdown: preserveMarkdown);
    } catch (e) {
      print('⚠️ [StreamingText] Text sanitization failed, using ASCII fallback: $e');
      return TextSanitizer.sanitizeToAscii(text);
    }
  }
}