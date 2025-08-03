import 'package:flutter/material.dart';
import 'dart:async';

class StreamingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration delay;
  final bool isStreaming;

  const StreamingText({
    super.key,
    required this.text,
    this.style,
    this.delay = const Duration(milliseconds: 20),
    this.isStreaming = true,
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