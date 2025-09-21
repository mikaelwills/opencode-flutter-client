import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/opencode_theme.dart';

class OpenCodeMarkdownStyles {
  static MarkdownStyleSheet get standard => MarkdownStyleSheet(
        p: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 14,
          color: OpenCodeTheme.text,
          height: 1.6,
        ),
        h1: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 24,
          color: OpenCodeTheme.primary,
          fontWeight: FontWeight.bold,
        ),
        h2: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 20,
          color: OpenCodeTheme.primary,
          fontWeight: FontWeight.bold,
        ),
        h3: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 16,
          color: OpenCodeTheme.primary,
          fontWeight: FontWeight.bold,
        ),
        code: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 13,
          color: OpenCodeTheme.success,
          backgroundColor: OpenCodeTheme.background,
        ),
        codeblockDecoration: const BoxDecoration(
          color: OpenCodeTheme.background,
          border: Border(
            left: BorderSide(
              color: OpenCodeTheme.primary,
              width: 4,
            ),
          ),
        ),
        blockquote: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 14,
          color: OpenCodeTheme.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        listBullet: const TextStyle(
          color: OpenCodeTheme.primary,
        ),
      );
}