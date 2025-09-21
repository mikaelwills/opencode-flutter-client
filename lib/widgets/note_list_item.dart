import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/opencode_theme.dart';
import '../models/note.dart';

/// List item component for displaying note preview information
/// Optimized for performance and accessibility
class NoteListItem extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;

  const NoteListItem({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
  });

  @override
  State<NoteListItem> createState() => _NoteListItemState();
}

class _NoteListItemState extends State<NoteListItem> {
  bool _isHovered = false;

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  void _handleLongPress() {
    if (widget.onLongPress != null) {
      HapticFeedback.heavyImpact();
      widget.onLongPress!();
    }
  }

  Color get _borderColor {
    if (widget.isSelected) return OpenCodeTheme.primary;
    if (_isHovered) return OpenCodeTheme.textSecondary.withValues(alpha: 0.4);
    return OpenCodeTheme.textSecondary.withValues(alpha: 0.2);
  }

  Color get _backgroundColor {
    if (widget.isSelected) return OpenCodeTheme.primary.withValues(alpha: 0.1);
    if (_isHovered) return OpenCodeTheme.surface;
    return OpenCodeTheme.surface;
  }

  Widget _buildFrontmatterTags() {
    if (widget.note.frontmatter == null || widget.note.frontmatter!.isEmpty) {
      return const SizedBox.shrink();
    }

    final tags = <Widget>[];
    final frontmatter = widget.note.frontmatter!;

    // Show specific frontmatter properties as tags
    if (frontmatter.containsKey('tags') && frontmatter['tags'] is List) {
      final noteTags = frontmatter['tags'] as List;
      for (final tag in noteTags.take(3)) {
        tags.add(_buildTag(tag.toString()));
      }
      if (noteTags.length > 3) {
        tags.add(_buildTag('+${noteTags.length - 3} more'));
      }
    } else {
      // Fallback: show that frontmatter exists
      tags.add(_buildTag('frontmatter'));
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: tags,
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: OpenCodeTheme.background,
        border: Border.all(
          color: OpenCodeTheme.textSecondary.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'FiraCode',
          fontSize: 10,
          color: OpenCodeTheme.textSecondary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: _backgroundColor,
          child: InkWell(
            onTap: _handleTap,
            onLongPress: _handleLongPress,
            splashColor: OpenCodeTheme.primary.withValues(alpha: 0.1),
            highlightColor: OpenCodeTheme.primary.withValues(alpha: 0.05),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.only(
                left: 16 + (widget.note.depth * 20.0), // Indent based on depth
                right: 16,
                top: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _borderColor,
                  width: widget.isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File name row
                  Row(
                    children: [
                      // File icon
                      Icon(
                        Icons.description_outlined,
                        color: widget.isSelected
                            ? OpenCodeTheme.primary
                            : OpenCodeTheme.textSecondary.withValues(alpha: 0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      // File name
                      Expanded(
                        child: Text(
                          widget.note.name,
                          style: TextStyle(
                            fontFamily: 'FiraCode',
                            fontSize: 14,
                            color: widget.isSelected
                                ? OpenCodeTheme.primary
                                : OpenCodeTheme.text,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Frontmatter tags
                  if (widget.note.frontmatter != null &&
                      widget.note.frontmatter!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildFrontmatterTags(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

