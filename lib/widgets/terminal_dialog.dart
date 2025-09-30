import 'package:flutter/material.dart';
import '../theme/opencode_theme.dart';
import 'terminal_input_field.dart';
import 'terminal_button.dart';

/// Terminal-style dialog component that follows OpenCode design system
/// Provides consistent styling and behavior for modal dialogs
class TerminalDialog extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<TerminalDialogAction> actions;
  final double? width;
  final double? height;
  final bool isDismissible;

  const TerminalDialog({
    super.key,
    required this.title,
    required this.children,
    required this.actions,
    this.width,
    this.height,
    this.isDismissible = true,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: width,
        height: height,
        constraints: const BoxConstraints(
          minWidth: 300,
          maxWidth: 500,
        ),
        decoration: BoxDecoration(
          color: OpenCodeTheme.background,
          border: Border.all(
            color: OpenCodeTheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: OpenCodeTheme.primary,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'FiraCode',
                        fontSize: 16,
                        color: OpenCodeTheme.text,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isDismissible)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.close,
                        color: OpenCodeTheme.textSecondary,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),

            // Actions
            if (actions.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: OpenCodeTheme.primary,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: actions.map((action) {
                    final isLast = action == actions.last;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: isLast ? 0 : 8,
                        ),
                        child: TerminalButton(
                          command: action.label,
                          type: action.type,
                          onPressed: action.onPressed,
                          width: double.infinity,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Action configuration for terminal dialogs
class TerminalDialogAction {
  final String label;
  final VoidCallback? onPressed;
  final TerminalButtonType type;

  const TerminalDialogAction({
    required this.label,
    this.onPressed,
    this.type = TerminalButtonType.neutral,
  });
}

/// Terminal-style input dialog for common use cases
class TerminalInputDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String confirmLabel;
  final String cancelLabel;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final String? initialValue;
  final ValueChanged<String>? onConfirm;

  const TerminalInputDialog({
    super.key,
    required this.title,
    required this.hintText,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.validator,
    this.keyboardType,
    this.initialValue,
    this.onConfirm,
  });

  @override
  State<TerminalInputDialog> createState() => _TerminalInputDialogState();
}

class _TerminalInputDialogState extends State<TerminalInputDialog> {
  late TextEditingController _controller;
  late GlobalKey<FormState> _formKey;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _formKey = GlobalKey<FormState>();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    if (_formKey.currentState?.validate() ?? false) {
      final value = _controller.text.trim();
      Navigator.of(context).pop(value);
      widget.onConfirm?.call(value);
    }
  }

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return TerminalDialog(
      title: widget.title,
      actions: [
        TerminalDialogAction(
          label: widget.cancelLabel,
          type: TerminalButtonType.neutral,
          onPressed: _handleCancel,
        ),
        TerminalDialogAction(
          label: widget.confirmLabel,
          type: TerminalButtonType.primary,
          onPressed: _handleConfirm,
        ),
      ],
      children: [
        Form(
          key: _formKey,
          child: TerminalInputField(
            controller: _controller,
            hintText: widget.hintText,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleConfirm(),
            prefixIcon: const Text(
              '❯',
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 14,
                color: OpenCodeTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}