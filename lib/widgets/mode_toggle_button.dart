import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/opencode_theme.dart';
import '../utils/session_validator.dart';

class ModeToggleButton extends StatelessWidget {
  final bool isInNotes;

  const ModeToggleButton({
    super.key,
    this.isInNotes = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isInNotes ? 'Switch to Chat' : 'Switch to Notes',
      button: true,
      child: IconButton(
        onPressed: () {
          if (isInNotes) {
            SessionValidator.navigateToChat(context);
          } else {
            context.go("/notes");
          }
        },
        tooltip: isInNotes ? 'Switch to Chat' : 'Switch to Notes',
        icon: Icon(
          isInNotes ? Icons.chat_outlined : Icons.note_outlined,
          color: OpenCodeTheme.text,
        ),
      ),
    );
  }
}