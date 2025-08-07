import 'package:flutter/material.dart';
import '../theme/opencode_theme.dart';

enum TerminalButtonType {
  primary,
  warning,
  danger,
  neutral,
}

class TerminalButton extends StatefulWidget {
  final String command;
  final VoidCallback? onPressed;
  final TerminalButtonType type;
  final bool isLoading;
  final String? loadingText;
  final double? width;
  final double height;

  const TerminalButton({
    super.key,
    required this.command,
    this.onPressed,
    this.type = TerminalButtonType.neutral,
    this.isLoading = false,
    this.loadingText,
    this.width,
    this.height = 48,
  });

  @override
  State<TerminalButton> createState() => _TerminalButtonState();
}

class _TerminalButtonState extends State<TerminalButton>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _spinnerController;
  late Animation<double> _glowAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _spinnerController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _glowController.repeat(reverse: true);
    if (widget.isLoading) {
      _spinnerController.repeat();
    }
  }

  @override
  void didUpdateWidget(TerminalButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _spinnerController.repeat();
      } else {
        _spinnerController.stop();
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _spinnerController.dispose();
    super.dispose();
  }

  Color get _borderColor {
    switch (widget.type) {
      case TerminalButtonType.primary:
        return OpenCodeTheme.primary;
      case TerminalButtonType.warning:
        return OpenCodeTheme.warning;
      case TerminalButtonType.danger:
        return OpenCodeTheme.error;
      case TerminalButtonType.neutral:
        return OpenCodeTheme.text;
    }
  }

  Color get _textColor {
    switch (widget.type) {
      case TerminalButtonType.primary:
        return OpenCodeTheme.primary;
      case TerminalButtonType.warning:
        return OpenCodeTheme.warning;
      case TerminalButtonType.danger:
        return OpenCodeTheme.error;
      case TerminalButtonType.neutral:
        return OpenCodeTheme.text;
    }
  }

  String get _displayText {
    if (widget.isLoading) {
      return widget.loadingText ?? '${widget.command.toUpperCase()}...';
    }
    return widget.command.toUpperCase();
  }

  Widget _buildSpinner() {
    const frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
    return AnimatedBuilder(
      animation: _spinnerController,
      builder: (context, child) {
        final frameIndex = (_spinnerController.value * frames.length).floor();
        return Text(
          frames[frameIndex % frames.length],
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 14,
            color: _textColor,
            fontWeight: FontWeight.w500,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: OpenCodeTheme.background,
              border: Border.all(
                color: _borderColor.withOpacity(_isHovered ? 0.5 : 0.35),
                width: _isHovered ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: _borderColor.withOpacity(
                    _isHovered ? _glowAnimation.value * 0.3 : 0.1,
                  ),
                  blurRadius: _isHovered ? 8 : 4,
                  spreadRadius: _isHovered ? 1 : 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(4),
                splashColor: _borderColor.withOpacity(0.1),
                highlightColor: _borderColor.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isLoading) ...[
                        _buildSpinner(),
                        const SizedBox(width: 8),
                      ],
                      
                      Flexible(
                        child: Text(
                          _displayText,
                          style: TextStyle(
                            fontFamily: 'FiraCode',
                            fontSize: 14,
                            color: _textColor,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}