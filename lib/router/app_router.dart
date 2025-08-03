import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/connect_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/main_scaffold.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/connect',
  routes: [
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/connect',
          name: 'connect',
          pageBuilder: (context, state) => _buildFadeTransitionPage(
            key: state.pageKey,
            child: const ConnectScreen(),
          ),
        ),
        GoRoute(
          path: '/chat',
          name: 'chat',
          pageBuilder: (context, state) => _buildFadeTransitionPage(
            key: state.pageKey,
            child: const ChatScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) => _buildFadeTransitionPage(
            key: state.pageKey,
            child: const SettingsScreen(),
          ),
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.error}'),
    ),
  ),
);

CustomTransitionPage<void> _buildFadeTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 50),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOutCirc).animate(animation),
        child: child,
      );
    },
  );
}

