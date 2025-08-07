import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../theme/opencode_theme.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_event.dart';
import '../blocs/session_list/session_list_bloc.dart';
import '../blocs/session_list/session_list_event.dart';
import '../blocs/session/session_bloc.dart';
import '../widgets/terminal_button.dart';
import 'package:dartssh2/dartssh2.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  bool _isLoading = true;
  bool _isRestarting = false;
  String _originalIP = '';
  int _originalPort = 4096;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController();
    _portController = TextEditingController();
    _loadCurrentIP();

    // Fallback timeout in case SharedPreferences hangs
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        _ipController.text = '192.168.1.161';
        _portController.text = '4096';
        _originalIP = '192.168.1.161';
        _originalPort = 4096;
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentIP() async {
    try {
      final configCubit = context.read<ConfigCubit>();
      final currentState = configCubit.state;

      String savedIP = '192.168.1.161';
      int savedPort = 4096;
      
      if (currentState is ConfigLoaded) {
        savedIP = currentState.serverIp;
        savedPort = currentState.port;
      } else {
        // Fallback to SharedPreferences if cubit state is not loaded
        final prefs = await SharedPreferences.getInstance();
        savedIP = prefs.getString('server_ip') ?? '192.168.1.161';
        savedPort = prefs.getInt('server_port') ?? 4096;
      }

      if (mounted) {
        _ipController.text = savedIP;
        _portController.text = savedPort.toString();
        _originalIP = savedIP;
        _originalPort = savedPort;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading IP and port: $e');
      // Fallback to default values if loading fails
      if (mounted) {
        _ipController.text = '192.168.1.161';
        _portController.text = '4096';
        _originalIP = '192.168.1.161';
        _originalPort = 4096;
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveIP() async {
    final newIP = _ipController.text.trim();
    final portText = _portController.text.trim();
    
    if (newIP.isEmpty) return;
    
    // Parse and validate port
    int newPort = 4096; // default
    if (portText.isNotEmpty) {
      final parsedPort = int.tryParse(portText);
      if (parsedPort == null || parsedPort < 1 || parsedPort > 65535) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Port must be a number between 1 and 65535'),
              backgroundColor: OpenCodeTheme.error,
            ),
          );
        }
        return;
      }
      newPort = parsedPort;
    }

    // Check if IP and port haven't changed
    if (newIP == _originalIP && newPort == _originalPort) {
      context.go('/chat');
      return;
    }

    try {
      // Update via ConfigCubit (this handles SharedPreferences automatically)
      final configCubit = context.read<ConfigCubit>();
      await configCubit.updateServer(newIP, port: newPort);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server updated to $newIP:$newPort'),
            backgroundColor: OpenCodeTheme.success,
          ),
        );
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save server settings: $e'),
            backgroundColor: OpenCodeTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _clearIP() async {
    try {
      // Reset ConnectionBloc state
      if (mounted) {
        context.read<ConnectionBloc>().add(const IntentionalDisconnect());
      }

      // Reset via ConfigCubit (this handles SharedPreferences automatically)
      final configCubit = context.read<ConfigCubit>();
      await configCubit.resetToDefault();

      // Clear the text fields
      _ipController.clear();
      _portController.clear();
      _originalIP = '';
      _originalPort = 4096;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('IP address cleared. App reset to first-launch state.'),
            backgroundColor: OpenCodeTheme.warning,
          ),
        );

        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear IP: $e'),
            backgroundColor: OpenCodeTheme.error,
          ),
        );
      }
    }
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

  Future<void> _restartServer() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OpenCodeTheme.surface,
        title: const Text(
          'Restart Server',
          style: TextStyle(color: OpenCodeTheme.text),
        ),
        content: const Text(
          'This will restart the OpenCode server. Continue?',
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
              'Restart',
              style: TextStyle(color: OpenCodeTheme.primary),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isRestarting = true;
    });

    try {
      final currentIP = _ipController.text.trim();
      if (currentIP.isEmpty) {
        throw Exception('IP address is required');
      }

      // Create SSH client
      final socket = await SSHSocket.connect(currentIP, 22);
      final client = SSHClient(
        socket,
        username: 'mikael',
        onPasswordRequest: () => '', // Password-less auth (key-based)
      );

      // Execute restart script
      client.execute('~/restart-opencode.sh');

      client.close();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Server restarted successfully'),
            backgroundColor: OpenCodeTheme.success,
          ),
        );

        // Trigger connection check after restart
        context.read<ConnectionBloc>().add(CheckConnection());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restart server: $e'),
            backgroundColor: OpenCodeTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRestarting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Loading settings...',
                  style: TextStyle(color: OpenCodeTheme.textSecondary),
                ),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // IP Address field
                Container(
                  height: 56,
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: OpenCodeTheme.primary,
                        width: 2,
                      ),
                      right: BorderSide(
                        color: OpenCodeTheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 12, right: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Terminal prompt symbol
                      const Text(
                        '❯',
                        style: TextStyle(
                          fontFamily: 'FiraCode',
                          fontSize: 14,
                          color: OpenCodeTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // IP Address input field
                      Flexible(
                        flex: 3,
                        child: TextField(
                          controller: _ipController,
                          style: const TextStyle(
                            fontFamily: 'FiraCode',
                            fontSize: 14,
                            color: OpenCodeTheme.text,
                            height: 1.4,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            filled: false,
                            hintText: 'IP Address',
                            hintStyle: TextStyle(
                              color: OpenCodeTheme.textSecondary,
                            ),
                          ),
                          maxLines: 1,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      
                      // Colon separator
                      const Text(
                        ':',
                        style: TextStyle(
                          fontFamily: 'FiraCode',
                          fontSize: 14,
                          color: OpenCodeTheme.text,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      // Port input field
                      Flexible(
                        flex: 1,
                        child: TextField(
                          controller: _portController,
                          style: const TextStyle(
                            fontFamily: 'FiraCode',
                            fontSize: 14,
                            color: OpenCodeTheme.text,
                            height: 1.4,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            filled: false,
                            hintText: 'Port',
                            hintStyle: TextStyle(
                              color: OpenCodeTheme.textSecondary,
                            ),
                          ),
                          maxLines: 1,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _saveIP(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TerminalButton(
                  command: 'connect',
                  type: TerminalButtonType.primary,
                  width: double.infinity,
                  onPressed: _saveIP,
                ),
                const SizedBox(height: 16),

                TerminalButton(
                  command: 'disconnect',
                  type: TerminalButtonType.warning,
                  width: double.infinity,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: OpenCodeTheme.surface,
                          title: const Text(
                            'Clear IP Address',
                            style: TextStyle(color: OpenCodeTheme.text),
                          ),
                          content: const Text(
                            'This will clear the saved IP address and reset the app to first-launch state. Are you sure?',
                            style: TextStyle(color: OpenCodeTheme.textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: OpenCodeTheme.textSecondary),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _clearIP();
                              },
                              child: const Text(
                                'Clear',
                                style: TextStyle(color: OpenCodeTheme.error),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),

                const Spacer(),
                TerminalButton(
                  command: 'delete_all_sessions',
                  type: TerminalButtonType.danger,
                  width: double.infinity,
                  onPressed: _deleteAllSessions,
                ),
                const SizedBox(height: 16),
                TerminalButton(
                  command: 'restart_server',
                  type: TerminalButtonType.neutral,
                  width: double.infinity,
                  isLoading: _isRestarting,
                  loadingText: 'restarting',
                  onPressed: _isRestarting ? null : _restartServer,
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
  }
}
