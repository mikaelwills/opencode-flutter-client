import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/session_validator.dart';
import '../theme/opencode_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_state.dart' as connection_states;
import '../blocs/connection/connection_event.dart';
import '../blocs/chat/chat_state.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../blocs/instance/instance_bloc.dart';
import '../blocs/instance/instance_event.dart';
import '../blocs/instance/instance_state.dart';
import '../models/opencode_instance.dart';
import '../services/sse_service.dart';
import '../widgets/terminal_ip_input.dart';
import 'chat_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  bool _isConnecting = false;
  String? _savedIP;
  int? _savedPort;

  @override
  void initState() {
    super.initState();
    _loadSavedIP();
    context.read<InstanceBloc>().add(LoadInstances());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedIP() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIP = prefs.getString('server_ip');
      final savedPort = prefs.getInt('server_port') ?? 4096;
      
      if (mounted) {
        setState(() {
          _savedIP = savedIP;
          _savedPort = savedPort;
          if (savedIP != null) {
            _ipController.text = savedIP;
            _portController.text = savedPort.toString();
          }
        });
      }
    } catch (e) {
      print('Error loading saved IP and port: $e');
    }
  }

  Future<void> _connectToIP() async {
    final ip = _ipController.text.trim();
    final portText = _portController.text.trim();
    
    if (ip.isEmpty) return;
    
    // Parse and validate port
    int port = 4096; // default
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
      port = parsedPort;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      // Update via ConfigCubit (this handles SharedPreferences automatically)
      final configCubit = context.read<ConfigCubit>();
      await configCubit.updateServer(ip, port: port);

      // Update saved state
      setState(() {
        _savedIP = ip;
        _savedPort = port;
      });

      // Trigger connection check
      if (mounted) {
        // Restart SSE service to connect to new server
        final sseService = context.read<SSEService>();
        sseService.restartConnection();
        
        // Restart ChatBloc SSE subscription to new server
        final chatBloc = context.read<ChatBloc>();
        chatBloc.restartSSESubscription();
        
        context.read<ConnectionBloc>().add(ResetConnection());
        context.read<ConnectionBloc>().add(CheckConnection());
        
        // Show save instance option after successful connection setup
        _showSaveInstanceOption();
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
    } finally {
      // Intentional delay for user feedback
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ConfigCubit, ConfigState>(
          listener: (context, configState) {
            // Update saved IP and port when config changes
            if (configState is ConfigLoaded) {
              setState(() {
                _savedIP = configState.serverIp == '0.0.0.0'
                    ? null
                    : configState.serverIp;
                _savedPort = configState.port;
              });
            }
          },
        ),
        BlocListener<ConnectionBloc, connection_states.ConnectionState>(
          listener: (context, connectionState) {
            // Auto-navigate to ChatScreen when session is ready
            if (connectionState is connection_states.Connected) {
              SessionValidator.navigateToChat(context);
            }
          },
        ),
      ],
      child: BlocBuilder<ConnectionBloc, connection_states.ConnectionState>(
        builder: (context, connectionState) {
          return BlocBuilder<ChatBloc, ChatState>(
            builder: (context, chatState) {
              final ipInputWidget = Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildIPInputUI(),
                  ],
                ),
              );

              if (_isConnecting) {
                return ipInputWidget;
              }

              // First priority: Show IP input if disconnected or no saved IP/port
              if (_savedIP == null || _savedPort == null ||
                  connectionState is connection_states.Disconnected) {
                return ipInputWidget;
              }

              // Second priority: Show chat screen when connected AND chat is ready
              if ((chatState is ChatReady || chatState is ChatSendingMessage) &&
                  connectionState is connection_states.Connected) {
                return const ChatScreen();
              }

              // Fallback: Show status UI for other states
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatusUI(connectionState, chatState),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildIPInputUI() {
    return Column(
      children: [
        // Show recent instances for quick access
        BlocBuilder<InstanceBloc, InstanceState>(
          builder: (context, instanceState) {
            if (instanceState is InstancesLoaded && instanceState.instances.isNotEmpty) {
              // Show up to 3 most recent instances
              final recentInstances = instanceState.instances.take(3).toList();
              
              return Column(
                children: [
                  ...recentInstances.map((instance) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: TerminalIPInput.instance(
                      instance: instance,
                      onConnect: () => _connectToInstanceFromConnect(instance),
                      maxWidth: 300,
                    ),
                  )),
                  if (instanceState.instances.length > 3) 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'and ${instanceState.instances.length - 3} more in settings...',
                        style: TextStyle(
                          color: OpenCodeTheme.text.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const Divider(
                    color: OpenCodeTheme.textSecondary,
                    height: 32,
                  ),
                  Text(
                    'Or connect manually:',
                    style: TextStyle(
                      color: OpenCodeTheme.text.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
        // Manual connection input
        TerminalIPInput.editable(
          ipController: _ipController,
          portController: _portController,
          onConnect: _connectToIP,
          isConnecting: _isConnecting,
          maxWidth: 300,
        ),
      ],
    );
  }

  Widget _buildStatusUI(
      connection_states.ConnectionState connectionState, ChatState chatState) {
    return Text(
      _getStatusText(connectionState, chatState),
      style: const TextStyle(
        color: OpenCodeTheme.textSecondary,
        fontSize: 14,
      ),
    );
  }

  String _getStatusText(
      connection_states.ConnectionState connectionState, ChatState chatState) {
    if (chatState is ChatError) return 'Error: ${chatState.error}';
    if (chatState is ChatSendingMessage) return 'Starting session...';

    if (connectionState is connection_states.Connected) {
      return 'Ready to start coding';
    }
    if (connectionState is connection_states.Reconnecting) {
      return 'Reconnecting to server...';
    }
    if (connectionState is connection_states.Disconnected) {
      return connectionState.reason ?? 'Connecting to server...';
    }
    return 'Connecting to server...';
  }


  Future<void> _connectToInstanceFromConnect(OpenCodeInstance instance) async {
    try {
      // Update the UI fields first
      setState(() {
        _ipController.text = instance.ip;
        _portController.text = instance.port;
        _savedIP = instance.ip;
        _savedPort = int.tryParse(instance.port);
      });

      // Update last used timestamp
      context.read<InstanceBloc>().add(UpdateLastUsed(instance.id));
      
      // Connect using the existing method
      await _connectToIP();
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

  void _showSaveInstanceOption() {
    // Check if this IP/port combination already exists as an instance
    final currentState = context.read<InstanceBloc>().state;
    if (currentState is InstancesLoaded) {
      final existingInstance = currentState.instances.firstWhere(
        (instance) => instance.ip == _savedIP && instance.port == _savedPort.toString(),
        orElse: () => OpenCodeInstance(
          id: '',
          name: '',
          ip: '',
          port: '',
          createdAt: DateTime.now(),
          lastUsed: DateTime.now(),
        ),
      );
      
      // Don't show save option if this instance already exists
      if (existingInstance.id.isNotEmpty) {
        return;
      }
    }

    // Show save option with a small delay to not interrupt the connection flow
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Save this connection as an instance for quick access?'),
            backgroundColor: OpenCodeTheme.primary,
            action: SnackBarAction(
              label: 'Save',
              textColor: OpenCodeTheme.background,
              onPressed: _showSaveInstanceDialog,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  void _showSaveInstanceDialog() {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Auto-suggest a name based on IP
    final suggestedName = _savedIP != null ? 'OpenCode $_savedIP' : 'OpenCode Instance';
    nameController.text = suggestedName;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: OpenCodeTheme.surface,
        title: const Text(
          'Save Instance',
          style: TextStyle(color: OpenCodeTheme.text),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Save "$_savedIP:$_savedPort" as an instance for quick access.',
                style: TextStyle(
                  color: OpenCodeTheme.text.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                style: const TextStyle(color: OpenCodeTheme.text),
                decoration: const InputDecoration(
                  labelText: 'Instance Name',
                  labelStyle: TextStyle(color: OpenCodeTheme.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: OpenCodeTheme.textSecondary),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: OpenCodeTheme.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: OpenCodeTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                _saveCurrentAsInstance(nameController.text.trim());
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text(
              'Save',
              style: TextStyle(color: OpenCodeTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _saveCurrentAsInstance(String name) {
    if (_savedIP == null || _savedPort == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No connection details to save'),
          backgroundColor: OpenCodeTheme.error,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final instance = OpenCodeInstance(
      id: '', // Will be generated by the bloc
      name: name,
      ip: _savedIP!,
      port: _savedPort.toString(),
      createdAt: now,
      lastUsed: now,
    );

    context.read<InstanceBloc>().add(AddInstance(instance));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved "$name" as an instance'),
        backgroundColor: OpenCodeTheme.success,
      ),
    );
  }
}
