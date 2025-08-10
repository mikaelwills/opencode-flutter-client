import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../theme/opencode_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_event.dart';
import '../blocs/instance/instance_bloc.dart';
import '../blocs/instance/instance_event.dart';
import '../blocs/instance/instance_state.dart';
import '../models/opencode_instance.dart';
import '../services/sse_service.dart';
import '../widgets/terminal_button.dart';
import '../widgets/terminal_ip_input.dart';
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
    context.read<InstanceBloc>().add(LoadInstances());

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
        // Restart SSE service to connect to new server
        final sseService = context.read<SSEService>();
        sseService.restartConnection();
        
        // Restart ChatBloc SSE subscription to new server
        final chatBloc = context.read<ChatBloc>();
        chatBloc.restartSSESubscription();
        
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

        context.go('/connect');
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
        : BlocListener<InstanceBloc, InstanceState>(
            listener: (context, state) {
              if (state is InstanceError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: OpenCodeTheme.error,
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TerminalIPInput.editable(
                    ipController: _ipController,
                    portController: _portController,
                    onConnect: _saveIP,
                    isConnecting: false,
                    maxWidth: double.infinity,
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TerminalButton(
                          command: 'disconnect',
                          type: TerminalButtonType.warning,
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
                                    style: TextStyle(
                                        color: OpenCodeTheme.textSecondary),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
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
                                        style: TextStyle(
                                            color: OpenCodeTheme.error),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TerminalButton(
                          command: 'restart_server',
                          type: TerminalButtonType.neutral,
                          isLoading: _isRestarting,
                          loadingText: 'restarting',
                          onPressed: _isRestarting ? null : _restartServer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: BlocBuilder<InstanceBloc, InstanceState>(
                      builder: (context, state) {
                        if (state is InstancesLoading) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: OpenCodeTheme.primary,
                            ),
                          );
                        }

                        if (state is InstancesLoaded) {
                          if (state.instances.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.storage_outlined,
                                    size: 48,
                                    color: OpenCodeTheme.text.withOpacity(0.6),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No saved instances',
                                    style: TextStyle(
                                      color:
                                          OpenCodeTheme.text.withOpacity(0.8),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap the + button above to add your first instance',
                                    style: TextStyle(
                                      color:
                                          OpenCodeTheme.text.withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: state.instances.length,
                            itemBuilder: (context, index) {
                              final instance = state.instances[index];
                              final isDeleting = state is InstanceDeleting &&
                                  state.deletingInstanceId == instance.id;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: TerminalIPInput.instance(
                                  instance: instance,
                                  onConnect: () => _connectToInstance(instance),
                                  onEdit: () => _showEditInstanceDialog(
                                      context, instance),
                                  isConnecting: isDeleting,
                                  maxWidth: double.infinity,
                                ),
                              );
                            },
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  Future<void> _connectToInstance(OpenCodeInstance instance) async {
    try {
      // Update last used timestamp
      context.read<InstanceBloc>().add(UpdateLastUsed(instance.id));

      // Update config with instance details
      await context.read<ConfigCubit>().updateServer(
            instance.ip,
            port: int.tryParse(instance.port) ?? 4096,
          );

      // Update the UI controllers
      setState(() {
        _ipController.text = instance.ip;
        _portController.text = instance.port;
        _originalIP = instance.ip;
        _originalPort = int.tryParse(instance.port) ?? 4096;
      });

      // Trigger connection
      if (mounted) {
        // Restart SSE service to connect to new instance
        final sseService = context.read<SSEService>();
        sseService.restartConnection();
        
        // Restart ChatBloc SSE subscription to new server
        final chatBloc = context.read<ChatBloc>();
        chatBloc.restartSSESubscription();
        
        context.read<ConnectionBloc>().add(ResetConnection());
        context.read<ConnectionBloc>().add(CheckConnection());

        // Navigate to chat screen
        context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to instance: $e'),
            backgroundColor: OpenCodeTheme.error,
          ),
        );
      }
    }
  }

  void _showEditInstanceDialog(
      BuildContext context, OpenCodeInstance instance) {
    _showInstanceDialog(context, title: 'Edit Instance', instance: instance);
  }

  void _showInstanceDialog(
    BuildContext context, {
    required String title,
    OpenCodeInstance? instance,
  }) {
    final nameController = TextEditingController(text: instance?.name ?? '');
    final ipController = TextEditingController(text: instance?.ip ?? '');
    final portController =
        TextEditingController(text: instance?.port ?? '4096');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: OpenCodeTheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: OpenCodeTheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        content: SizedBox(
          width: 350,
          child: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Instance Name Input
                  Container(
                    height: 52,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
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
                        Expanded(
                          child: TextFormField(
                            controller: nameController,
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
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              hintText: 'Instance Name',
                              hintStyle:
                                  TextStyle(color: OpenCodeTheme.textSecondary),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Name is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // IP and Port Input
                  Container(
                    height: 52,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
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
                        Flexible(
                          flex: 10,
                          child: TextFormField(
                            controller: ipController,
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
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              hintText: 'IP Address',
                              hintStyle:
                                  TextStyle(color: OpenCodeTheme.textSecondary),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'IP address is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2.0),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontFamily: 'FiraCode',
                              fontSize: 14,
                              color: OpenCodeTheme.text,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 4,
                          child: TextFormField(
                            controller: portController,
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
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              hintText: 'Port',
                              hintStyle:
                                  TextStyle(color: OpenCodeTheme.textSecondary),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Port is required';
                              }
                              final port = int.tryParse(value.trim());
                              if (port == null || port < 1 || port > 65535) {
                                return 'Port must be between 1 and 65535';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (instance != null) ...[
                  TerminalButton(
                    command: 'delete',
                    type: TerminalButtonType.danger,
                    width: double.infinity,
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _showDeleteConfirmation(context, instance);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TerminalButton(
                  command: 'cancel',
                  type: TerminalButtonType.neutral,
                  width: double.infinity,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                const SizedBox(height: 16),
                TerminalButton(
                  command: instance == null ? 'add' : 'update',
                  type: TerminalButtonType.primary,
                  width: double.infinity,
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      final now = DateTime.now();
                      final newInstance = OpenCodeInstance(
                        id: instance?.id ?? '',
                        name: nameController.text.trim(),
                        ip: ipController.text.trim(),
                        port: portController.text.trim(),
                        createdAt: instance?.createdAt ?? now,
                        lastUsed: instance?.lastUsed ?? now,
                      );

                      if (instance == null) {
                        context
                            .read<InstanceBloc>()
                            .add(AddInstance(newInstance));
                      } else {
                        context
                            .read<InstanceBloc>()
                            .add(UpdateInstance(newInstance));
                      }

                      Navigator.of(dialogContext).pop();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, OpenCodeInstance instance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OpenCodeTheme.surface,
        title: const Text(
          'Delete Instance',
          style: TextStyle(color: OpenCodeTheme.text),
        ),
        content: Text(
          'Are you sure you want to delete "${instance.name}"? This action cannot be undone.',
          style: const TextStyle(color: OpenCodeTheme.textSecondary),
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
              context.read<InstanceBloc>().add(DeleteInstance(instance.id));
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: OpenCodeTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
