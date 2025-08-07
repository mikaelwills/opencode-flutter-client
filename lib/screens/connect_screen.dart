import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../theme/opencode_theme.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_state.dart' as connection_states;
import '../blocs/connection/connection_event.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_state.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
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
        context.read<ConnectionBloc>().add(ResetConnection());
        context.read<ConnectionBloc>().add(CheckConnection());
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
              context.go('/chat');
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
        Container(
          constraints: const BoxConstraints(maxWidth: 300),
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                  onSubmitted: (_) => _connectToIP(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          constraints: const BoxConstraints(maxWidth: 300),
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isConnecting ? null : _connectToIP,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: OpenCodeTheme.primary,
              elevation: 0,
              side: const BorderSide(
                color: OpenCodeTheme.primary,
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: _isConnecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        OpenCodeTheme.primary,
                      ),
                    ),
                  )
                : const Text('Connect'),
          ),
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
}
