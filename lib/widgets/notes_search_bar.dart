import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/opencode_theme.dart';
import 'terminal_input_field.dart';

/// Search bar component for filtering notes
/// Provides terminal-style search interface with enhanced UX features
class NotesSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final bool isLoading;
  final String? errorText;
  final double? height;

  const NotesSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
    this.isLoading = false,
    this.errorText,
    this.height,
  });

  @override
  State<NotesSearchBar> createState() => _NotesSearchBarState();
}

class _NotesSearchBarState extends State<NotesSearchBar> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleClear() {
    widget.controller.clear();
    widget.onChanged('');
    widget.onClear?.call();
    // Provide haptic feedback
    HapticFeedback.lightImpact();
  }

  Widget? _buildSuffixIcon() {
    if (widget.controller.text.isEmpty) return null;

    return IconButton(
      onPressed: _handleClear,
      icon: const Icon(
        Icons.clear,
        color: OpenCodeTheme.textSecondary,
        size: 18,
      ),
      tooltip: 'Clear search',
      splashRadius: 20,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TerminalInputField(
          controller: widget.controller,
          hintText: ' Search notes...',
          onChanged: widget.onChanged,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          suffixIcon: _buildSuffixIcon(),
          height: widget.height,
          showBorders: false,
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              widget.errorText!,
              style: const TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 12,
                color: OpenCodeTheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
