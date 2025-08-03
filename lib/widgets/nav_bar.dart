import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/opencode_theme.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key});

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (currentLocation == '/settings') ...[
            GestureDetector(
                onTap: () => context.go("/chat"),
                child: const Icon(Icons.arrow_left)),
          ],
          if (currentLocation == '/chat') ...[const Text("OpenCode Mobile")],
                   if (currentLocation == '/chat') ...[
            GestureDetector(
                onTap: () => context.go("/settings"),
                child: const Icon(Icons.settings)),
          ],
        ],
      ),
    );
  }
}



