import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/opencode_theme.dart';
import '../models/note.dart';

class FolderListItem extends StatefulWidget {
  final Folder folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isExpanded;

  const FolderListItem({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.isExpanded = false,
  });

  @override
  State<FolderListItem> createState() => _FolderListItemState();
}

class _FolderListItemState extends State<FolderListItem> {
  bool _isHovered = false;

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
                left: 16 + (widget.folder.depth * 20.0), // Indent based on depth
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
              child: Row(
                children: [
                  // Expand/collapse chevron
                  Icon(
                    widget.isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: widget.isSelected
                        ? OpenCodeTheme.primary
                        : OpenCodeTheme.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  // Folder icon
                  Icon(
                    Icons.folder_outlined,
                    color: widget.isSelected
                        ? OpenCodeTheme.primary
                        : OpenCodeTheme.primary.withValues(alpha: 0.7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  // Folder name
                  Expanded(
                    child: Text(
                      widget.folder.name,
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
            ),
          ),
        ),
      ),
    );
  }

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
}