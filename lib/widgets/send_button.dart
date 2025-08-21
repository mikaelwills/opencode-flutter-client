import 'package:flutter/material.dart';
import '../theme/opencode_theme.dart';

class SendButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SendButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.keyboard_arrow_up),
      color: Colors.white,
      tooltip: 'Send message',
      style: IconButton.styleFrom(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

