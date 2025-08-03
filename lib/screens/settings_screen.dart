import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../theme/opencode_theme.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_event.dart';
import 'package:dartssh2/dartssh2.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipController;
  bool _isLoading = true;
  bool _isRestarting = false;
  String _originalIP = '';

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController();
    _loadCurrentIP();

    // Fallback timeout in case SharedPreferences hangs
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        _ipController.text = '192.168.1.161';
        _originalIP = '192.168.1.161';
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentIP() async {
    try {
      final configCubit = context.read<ConfigCubit>();
      final currentState = configCubit.state;

      String savedIP = '192.168.1.161';
      if (currentState is ConfigLoaded) {
        savedIP = currentState.serverIp;
      } else {
        // Fallback to SharedPreferences if cubit state is not loaded
        final prefs = await SharedPreferences.getInstance();
        savedIP = prefs.getString('server_ip') ?? '192.168.1.161';
      }

      if (mounted) {
        _ipController.text = savedIP;
        _originalIP = savedIP;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading IP: $e');
      // Fallback to default IP if loading fails
      if (mounted) {
        _ipController.text = '192.168.1.161';
        _originalIP = '192.168.1.161';
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveIP() async {
    final newIP = _ipController.text.trim();
    if (newIP.isEmpty) return;

    // Check if IP hasn't changed
    if (newIP == _originalIP) {
      context.go('/chat');
      return;
    }

    try {
      // Update via ConfigCubit (this handles SharedPreferences automatically)
      final configCubit = context.read<ConfigCubit>();
      await configCubit.updateServer(newIP);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server IP updated to $newIP'),
            backgroundColor: OpenCodeTheme.success,
          ),
        );
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save IP: $e'),
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
        context
            .read<ConnectionBloc>()
            .add(const ConnectionLost(reason: 'IP cleared by user'));
      }

      // Reset via ConfigCubit (this handles SharedPreferences automatically)
      final configCubit = context.read<ConfigCubit>();
      await configCubit.resetToDefault();

      // Clear the text field
      _ipController.clear();
      _originalIP = '';

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

                      // Input field
                      Flexible(
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
                            hintText: 'Enter IP address',
                            hintStyle: TextStyle(
                              color: OpenCodeTheme.textSecondary,
                            ),
                          ),
                          maxLines: 1,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _saveIP(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saveIP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: OpenCodeTheme.text,
                      elevation: 0,
                      side: const BorderSide(
                        color: Color(0xFF333333),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(height: 16),

                // Clear IP button for testing
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            backgroundColor: const Color(0xFF1A1A1A),
                            title: const Text(
                              'Clear IP Address',
                              style: TextStyle(color: OpenCodeTheme.text),
                            ),
                            content: const Text(
                              'This will clear the saved IP address and reset the app to first-launch state. Are you sure?',
                              style:
                                  TextStyle(color: OpenCodeTheme.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                      color: OpenCodeTheme.textSecondary),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: OpenCodeTheme.error,
                      elevation: 0,
                      side: const BorderSide(
                        color: Color(0xFF333333),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Disconnect'),
                  ),
                ),

                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isRestarting ? null : _restartServer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      foregroundColor: OpenCodeTheme.text,
                      elevation: 0,
                      side: const BorderSide(
                        color: Color(0xFF333333),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: _isRestarting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                OpenCodeTheme.text,
                              ),
                            ),
                          )
                        : const Text('Restart Server'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
  }
}
