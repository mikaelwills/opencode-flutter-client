import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:opencode_flutter_client/blocs/session/session_bloc.dart';
import 'package:opencode_flutter_client/blocs/session/session_state.dart';

class SessionValidator {
  /// Checks if there is a valid, loaded session.
  static bool isValidSession(BuildContext context) {
    final sessionState = context.read<SessionBloc>().state;
    // A session is considered valid if it's in the "Loaded" state,
    // meaning we have session data.
    return sessionState is SessionLoaded;
  }

  /// Navigates to the chat screen only if the session is valid.
  /// Otherwise, navigates to the connect screen.
  static void navigateToChat(BuildContext context) {
    if (isValidSession(context)) {
      context.go('/chat');
    } else {
      // Silently redirect to connect screen if session is not ready.
      // This prevents navigating to a broken chat screen.
      context.go('/connect');
    }
  }
}
