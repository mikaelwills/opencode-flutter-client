import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../theme/opencode_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_event.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key});

  void _onNewSessionPressed(BuildContext context) {
    context.read<ChatBloc>().add(ClearChat());
    context.read<SessionBloc>().add(CreateSession());
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = GoRouterState.of(context).uri.toString();

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: OpenCodeTheme.surface,
      ),
      child: Row(
        children: [
          if (currentLocation == '/settings') ...[
            GestureDetector(
                onTap: () => context.go("/chat"),
                child: const Icon(Icons.arrow_left, color: OpenCodeTheme.text)),
          ],
          if (currentLocation == '/sessions') ...[
            GestureDetector(
                onTap: () => context.go("/chat"),
                child: const Icon(Icons.arrow_left, color: OpenCodeTheme.text)),
          ],
          if (currentLocation == '/provider-list') ...[
            GestureDetector(
                onTap: () => context.go("/chat"),
                child: const Icon(Icons.arrow_left, color: OpenCodeTheme.text)),
          ],
          if (currentLocation == '/chat') ...[
            GestureDetector(
              onTap: () => context.go("/sessions"),
              child: const Icon(Icons.list_outlined, color: OpenCodeTheme.text),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () => _onNewSessionPressed(context),
              child: const Icon(Icons.create_outlined,
                  color: OpenCodeTheme.text),
            ),
          ],
          const Spacer(),
          if (currentLocation == '/chat' || currentLocation == '/sessions')
            GestureDetector(
                onTap: () => context.go("/settings"),
                child: const Icon(Icons.settings, color: OpenCodeTheme.text)),
        ],
      ),
    );
  }
}
