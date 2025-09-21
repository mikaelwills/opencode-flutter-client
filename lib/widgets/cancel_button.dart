import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/opencode_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';

class CancelButton extends StatelessWidget {
  final String sessionId;

  const CancelButton({
    super.key,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        context.read<ChatBloc>().add(CancelCurrentOperation());
      },
      icon: const Icon(Icons.stop),
      color: OpenCodeTheme.error,
      tooltip: 'Cancel operation (^C)',
      style: IconButton.styleFrom(
        backgroundColor: OpenCodeTheme.error.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}