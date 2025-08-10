import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/session_validator.dart';
import '../theme/opencode_theme.dart';
import '../blocs/session_list/session_list_bloc.dart';
import '../blocs/session_list/session_list_event.dart';
import '../blocs/session_list/session_list_state.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_event.dart';
import '../blocs/session/session_state.dart';
import '../models/session.dart';
import '../widgets/terminal_button.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  @override
  void initState() {
    super.initState();
    // Load sessions when screen initializes
    context.read<SessionListBloc>().add(LoadSessions());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionListBloc, SessionListState>(
        builder: (context, state) {
          if (state is SessionListLoading) {
            return const Center(
              child: CircularProgressIndicator(
                color: OpenCodeTheme.primary,
              ),
            );
          }

          if (state is SessionListError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: OpenCodeTheme.text.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load sessions',
                    style: TextStyle(
                      color: OpenCodeTheme.text.withOpacity(0.8),
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: TextStyle(
                      color: OpenCodeTheme.text.withOpacity(0.6),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.read<SessionListBloc>().add(LoadSessions());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OpenCodeTheme.primary,
                      foregroundColor: OpenCodeTheme.background,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is SessionListLoaded) {
            if (state.sessions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: OpenCodeTheme.text.withOpacity(0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No sessions yet',
                      style: TextStyle(
                        color: OpenCodeTheme.text.withOpacity(0.8),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a new conversation to create your first session',
                      style: TextStyle(
                        color: OpenCodeTheme.text.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<SessionListBloc>().add(RefreshSessions());
              },
              child: BlocBuilder<SessionBloc, SessionState>(
                builder: (context, sessionState) {
                  final currentSessionId = context.read<SessionBloc>().currentSessionId;
                  
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: state.sessions.length,
                          itemBuilder: (context, index) {
                            final session = state.sessions[index];
                            final isDeleting = state is SessionDeleting && 
                                (state as SessionDeleting).deletingSessionId == session.id;
                            final isCurrentSession = session.id == currentSessionId;

                            return SessionCard(
                              session: session,
                              isDeleting: isDeleting,
                              isCurrentSession: isCurrentSession,
                              onTap: () => _selectSession(context, session),
                              onDelete: () => _showDeleteConfirmation(context, session),
                            );
                          },
                        ),
                      ),
                      if (state.sessions.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TerminalButton(
                            command: 'delete_all_sessions',
                            type: TerminalButtonType.danger,
                            width: double.infinity,
                            onPressed: _deleteAllSessions,
                          ),
                        ),
                      ],
                    ],
                  );
                }
              ),
            );
          }

          return const SizedBox.shrink();
        },
      );
  }

  void _selectSession(BuildContext context, Session session) {
    // Set current session in SessionBloc - ChatBloc will automatically load messages
    context.read<SessionBloc>().add(SetCurrentSession(session.id));
    
    // Navigate to chat screen
    SessionValidator.navigateToChat(context);
  }

  void _showDeleteConfirmation(BuildContext context, Session session) {
    // Check if this is the current active session
    final currentSessionId = context.read<SessionBloc>().currentSessionId;
    
    // If this is the current active session, show info dialog instead
    if (currentSessionId == session.id) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: OpenCodeTheme.surface,
            title: const Text(
              'Cannot Delete Active Session',
              style: TextStyle(color: OpenCodeTheme.text),
            ),
            content: const Text(
              'You cannot delete the currently active session. Please switch to another session first or go to the chat screen to start a new session.',
              style: TextStyle(color: OpenCodeTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(color: OpenCodeTheme.primary),
                ),
              ),
            ],
          );
        },
      );
      return;
    }
    
    // Show normal delete confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: OpenCodeTheme.surface,
          title: const Text(
            'Delete Session',
            style: TextStyle(color: OpenCodeTheme.text),
          ),
          content: Text(
            'Are you sure you want to delete this session? This action cannot be undone.',
            style: TextStyle(color: OpenCodeTheme.text.withOpacity(0.8)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: OpenCodeTheme.text.withOpacity(0.6)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<SessionListBloc>().add(DeleteSession(session.id));
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAllSessions() async {
    // Capture context-dependent values before async operations
    final currentSessionId = context.read<SessionBloc>().currentSessionId;
    
    final sessionListBloc = context.read<SessionListBloc>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OpenCodeTheme.surface,
        title: const Text(
          'Delete All Sessions',
          style: TextStyle(color: OpenCodeTheme.text),
        ),
        content: const Text(
          'This will permanently delete all sessions and cannot be undone. Are you sure?',
          style: TextStyle(color: OpenCodeTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: OpenCodeTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete All',
              style: TextStyle(color: OpenCodeTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Trigger delete all sessions event with exclusion
      sessionListBloc.add(DeleteAllSessions(excludeSessionId: currentSessionId));
      
      if (mounted) {
        final message = currentSessionId != null
            ? 'Deleting all sessions except the active one...'
            : 'Deleting all sessions...';
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: OpenCodeTheme.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to delete all sessions: $e'),
            backgroundColor: OpenCodeTheme.error,
          ),
        );
      }
    }
  }
}

class SessionCard extends StatelessWidget {
  final Session session;
  final bool isDeleting;
  final bool isCurrentSession;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const SessionCard({
    super.key,
    required this.session,
    required this.isDeleting,
    required this.isCurrentSession,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isCurrentSession ? OpenCodeTheme.primary.withOpacity(0.1) : OpenCodeTheme.surface,
      elevation: isCurrentSession ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: isCurrentSession 
          ? BoxDecoration(
              border: Border.all(
                color: OpenCodeTheme.primary.withOpacity(0.3),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
        child: InkWell(
          onTap: isDeleting ? null : onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.description.isEmpty 
                                ? 'Session ${session.id}'
                                : session.description,
                            style: TextStyle(
                              color: OpenCodeTheme.text,
                              fontSize: 16,
                              fontWeight: isCurrentSession ? FontWeight.w600 : FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: OpenCodeTheme.text.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(session.lastUpdated),
                          style: TextStyle(
                            color: OpenCodeTheme.text.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                        if (session.isLoadingSummary) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: OpenCodeTheme.primary.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isDeleting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.red,
                  ),
                )
              else
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}