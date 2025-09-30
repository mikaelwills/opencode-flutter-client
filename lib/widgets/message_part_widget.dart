import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/opencode_theme.dart';
import '../models/message_part.dart';
import '../utils/text_sanitizer.dart';
import '../utils/tool_display_helper.dart';

class MessagePartWidget extends StatelessWidget {
  final MessagePart part;
  final bool isStreaming;

  const MessagePartWidget({
    super.key,
    required this.part,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (part.type) {
      case 'text':
        return _buildTextPart();
      case 'tool':
        return _buildToolPart();
      case 'diff':
        return _buildDiffPart();
      case 'plan-options':
        return _buildPlanOptionsPart();
      case 'step-start':
        return const SizedBox.shrink();
      case 'step-finish':
        return const SizedBox.shrink();
      default:
        return _buildTextPart();
    }
  }

  Widget _buildTextPart() {
    final content = part.content ?? '';
    
    if (content.isEmpty) {
      print('❌ [MessagePartWidget] Text part has empty content!');
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MarkdownBody(
        data: _safeTextSanitize(content, preserveMarkdown: true),
        styleSheet: MarkdownStyleSheet(
          p: OpenCodeTextStyles.terminal,
          code: OpenCodeTextStyles.code,
          codeblockDecoration: BoxDecoration(
            color: OpenCodeTheme.surface,
            borderRadius: BorderRadius.circular(4),
          ),
          codeblockPadding: const EdgeInsets.all(8),
          blockquote: OpenCodeTextStyles.terminal.copyWith(
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
          h1: OpenCodeTextStyles.terminal.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          h2: OpenCodeTextStyles.terminal.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          h3: OpenCodeTextStyles.terminal.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          listBullet: OpenCodeTextStyles.terminal,
          listIndent: 16,
        ),
        selectable: true,
      ),
    );
  }

  Widget _buildToolPart() {
    final toolName = ToolDisplayHelper.getDisplayName(part);
    final toolStatus = part.metadata?['status'] ?? 'running';
    final toolOutput = part.content ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OpenCodeTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getToolStatusColor(toolStatus),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tool header
          Row(
            children: [
              Text(
                '│',
                style: OpenCodeTextStyles.terminal.copyWith(
                  color: _getToolStatusColor(toolStatus),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _safeTextSanitize(toolName, preserveMarkdown: false),
                style: OpenCodeTextStyles.terminal.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _getToolStatusColor(toolStatus),
                ),
              ),
              const Spacer(),
              Text(
                toolStatus,
                style: OpenCodeTextStyles.terminal.copyWith(
                  fontSize: 12,
                  color: OpenCodeTheme.textSecondary,
                ),
              ),
            ],
          ),
          
          // Tool output
          if (toolOutput.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: OpenCodeTheme.background,
                borderRadius: BorderRadius.circular(4),
              ),
               child: SelectableText(
                 _safeTextSanitize(toolOutput, preserveMarkdown: true),
                 style: OpenCodeTextStyles.code,
               ),            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiffPart() {
    final language = part.metadata?['language'] ?? 'diff';
    final content = part.content ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OpenCodeTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.difference,
                size: 16,
                color: OpenCodeTheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Code Changes',
                style: OpenCodeTextStyles.terminal.copyWith(
                  fontWeight: FontWeight.w600,
                  color: OpenCodeTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HighlightView(
            content,
            language: language,
            theme: const {
              'root': TextStyle(
                backgroundColor: OpenCodeTheme.surface,
                color: OpenCodeTheme.text,
              ),
              'comment': TextStyle(color: Color(0xFF6A737D)),
              'keyword': TextStyle(color: Color(0xFFD73A49)),
              'string': TextStyle(color: Color(0xFF032F62)),
            },
            textStyle: OpenCodeTextStyles.code,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOptionsPart() {
    final options = part.metadata?['options'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OpenCodeTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: OpenCodeTheme.primary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.list,
                size: 16,
                color: OpenCodeTheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Plan Options',
                style: OpenCodeTextStyles.terminal.copyWith(
                  fontWeight: FontWeight.w600,
                  color: OpenCodeTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value.toString();
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: InkWell(
                onTap: () {
                  // TODO: Handle plan option selection
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${index + 1}.',
                        style: OpenCodeTextStyles.terminal.copyWith(
                          color: OpenCodeTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          option,
                          style: OpenCodeTextStyles.terminal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }





  /// Safe text sanitization with fallback handling
  String _safeTextSanitize(String text, {bool preserveMarkdown = true}) {
    try {
      return TextSanitizer.sanitize(text, preserveMarkdown: preserveMarkdown);
    } catch (e) {
      print('⚠️ [MessagePartWidget] Text sanitization failed, using ASCII fallback: $e');
      return TextSanitizer.sanitizeToAscii(text);
    }
  }

  Color _getToolStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'success':
        return OpenCodeTheme.success;
      case 'error':
      case 'failed':
        return OpenCodeTheme.error;
      case 'running':
      case 'in_progress':
        return OpenCodeTheme.warning;
      default:
        return OpenCodeTheme.primary;
    }
  }
}