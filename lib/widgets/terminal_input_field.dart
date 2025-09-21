import 'package:flutter/material.dart';
import '../theme/opencode_theme.dart';

/// Reusable terminal-style input field component
/// Follows OpenCode design system with consistent styling
class TerminalInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLines;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool compact;
  final double? height;

  const TerminalInputField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.validator,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLines = 1,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.compact = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => focusNode?.requestFocus(),
      child: Container(
           height: height ?? 52,
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          if (prefixIcon != null) ...[
            prefixIcon!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: validator != null
                ? TextFormField(
                    controller: controller,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      fontFamily: 'FiraCode',
                      fontSize: 14,
                      color: OpenCodeTheme.text,
                      height: compact ? 1.0 : 1.4,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: true,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: hintText,
                      hintStyle:
                          const TextStyle(color: OpenCodeTheme.textSecondary),
                    ),
                    keyboardType: keyboardType,
                    maxLines: maxLines,
                    enabled: enabled,
                    focusNode: focusNode,
                    textInputAction: textInputAction,
                    onChanged: onChanged,
                    onFieldSubmitted: onSubmitted,
                    validator: validator,
                  )
                : TextField(
                    controller: controller,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      fontFamily: 'FiraCode',
                      fontSize: 14,
                      color: OpenCodeTheme.text,
                      height: compact ? 1.0 : 1.4,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: true,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: hintText,
                      hintStyle:
                          const TextStyle(color: OpenCodeTheme.textSecondary),
                    ),
                    keyboardType: keyboardType,
                    maxLines: maxLines,
                    enabled: enabled,
                    focusNode: focusNode,
                    textInputAction: textInputAction,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                  ),
          ),
          if (suffixIcon != null) ...[
            const SizedBox(width: 12),
            suffixIcon!,
          ],
        ],
        ),
      ),
    );
  }
}

