import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../utils/session_validator.dart';
import '../theme/opencode_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/config/config_cubit.dart';
import '../blocs/config/config_state.dart';
import '../blocs/connection/connection_bloc.dart';
import '../blocs/connection/connection_event.dart';
import '../blocs/instance/instance_bloc.dart';
import '../blocs/instance/instance_event.dart';
import '../blocs/instance/instance_state.dart';
import '../blocs/obsidian_instance/obsidian_instance_bloc.dart';
import '../blocs/obsidian_instance/obsidian_instance_event.dart';
import '../blocs/obsidian_instance/obsidian_instance_state.dart';
import '../blocs/obsidian_connection/obsidian_connection_cubit.dart';
import '../blocs/obsidian_connection/obsidian_connection_state.dart' as obsidian_connection_states;
import '../models/opencode_instance.dart';
import '../models/obsidian_instance.dart';
import '../services/sse_service.dart';
import '../widgets/terminal_button.dart';
import '../widgets/instance_list_item.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  void initState() {
    super.initState();
    context.read<InstanceBloc>().add(LoadInstances());
    context.read<ObsidianInstanceBloc>().add(LoadObsidianInstances());
  }

  @override
  void dispose() {
    super.dispose();
  }




  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<InstanceBloc, InstanceState>(
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
        ),
        BlocListener<ObsidianInstanceBloc, ObsidianInstanceState>(
          listener: (context, state) {
            if (state is ObsidianInstanceError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: OpenCodeTheme.error,
                ),
              );
            }
          },
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOpenCodeInstancesSection(),
                  const SizedBox(height: 32),
                  _buildObsidianInstancesSection(),
                ],
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
        SessionValidator.navigateToChat(context);
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

  Future<void> _connectToObsidianInstance(ObsidianInstance instance) async {
    try {
      // Update last used timestamp
      context.read<ObsidianInstanceBloc>().add(UpdateObsidianLastUsed(instance.id));

      // Connect to Obsidian instance
      await context.read<ObsidianConnectionCubit>().connectToInstance(instance);

      if (mounted) {
        // Navigate to notes screen
        context.go('/notes');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to Obsidian instance: $e'),
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

  void _showEditObsidianInstanceDialog(
      BuildContext context, ObsidianInstance instance) {
    _showObsidianInstanceDialog(context, title: 'Edit Obsidian Instance', instance: instance);
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
            color: OpenCodeTheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        content: SizedBox(
          width: 300,
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Instance Name Input
                  Container(
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
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
                  const SizedBox(height: 12),
                  // IP and Port Input
                  Container(
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
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
                          flex: 8,
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
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
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
                          flex: 5,
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
            padding: const EdgeInsets.fromLTRB(4.0, 0.0, 4.0, 4.0),
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
                  const SizedBox(height: 12),
                ],
                TerminalButton(
                  command: 'cancel',
                  type: TerminalButtonType.neutral,
                  width: double.infinity,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                const SizedBox(height: 12),
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

  void _showObsidianInstanceDialog(
    BuildContext context, {
    required String title,
    ObsidianInstance? instance,
  }) {
    final nameController = TextEditingController(text: instance?.name ?? '');
    final ipController = TextEditingController(text: instance?.ip ?? '');
    final portController =
        TextEditingController(text: instance?.port ?? '27123');
    final apiKeyController = TextEditingController(text: instance?.apiKey ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: OpenCodeTheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: OpenCodeTheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        content: SizedBox(
          width: 300,
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Instance Name Input
                  Container(
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
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
                  const SizedBox(height: 12),
                  // IP and Port Input
                  Container(
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
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
                          flex: 8,
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
                          padding: EdgeInsets.symmetric(horizontal: 4.0),
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
                          flex: 5,
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
                  const SizedBox(height: 12),
                  // API Key Input
                  Container(
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
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
                            controller: apiKeyController,
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
                              hintText: 'API Key',
                              hintStyle:
                                  TextStyle(color: OpenCodeTheme.textSecondary),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'API Key is required';
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
            padding: const EdgeInsets.fromLTRB(4.0, 0.0, 4.0, 4.0),
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
                      _showDeleteObsidianConfirmation(context, instance);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TerminalButton(
                  command: 'cancel',
                  type: TerminalButtonType.neutral,
                  width: double.infinity,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                const SizedBox(height: 12),
                TerminalButton(
                  command: instance == null ? 'add' : 'update',
                  type: TerminalButtonType.primary,
                  width: double.infinity,
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      final now = DateTime.now();
                      final newInstance = ObsidianInstance(
                        id: instance?.id ?? '',
                        name: nameController.text.trim(),
                        ip: ipController.text.trim(),
                        port: portController.text.trim(),
                        apiKey: apiKeyController.text.trim(),
                        createdAt: instance?.createdAt ?? now,
                        lastUsed: instance?.lastUsed ?? now,
                      );

                      if (instance == null) {
                        context
                            .read<ObsidianInstanceBloc>()
                            .add(AddObsidianInstance(newInstance));
                      } else {
                        context
                            .read<ObsidianInstanceBloc>()
                            .add(UpdateObsidianInstance(newInstance));
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

  Widget _buildOpenCodeInstancesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OpenCode Instances (Chat)',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: OpenCodeTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<InstanceBloc, InstanceState>(
          builder: (context, state) {
            if (state is InstancesLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: OpenCodeTheme.primary,
                ),
              );
            }

            if (state is InstancesLoaded) {
              return Column(
                children: [
                  if (state.instances.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: OpenCodeTheme.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'No OpenCode instances saved',
                          style: TextStyle(
                            fontFamily: 'FiraCode',
                            fontSize: 14,
                            color: OpenCodeTheme.text.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    )
                  else
                    ...state.instances.map((instance) {
                      return InstanceListItem(
                        name: instance.name,
                        ip: instance.ip,
                        port: instance.port,
                        isConnected: _isCurrentlyConnected(instance),
                        onTap: () => _showEditInstanceDialog(context, instance),
                        onConnectionTap: () => _connectToInstance(instance),
                      );
                    }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TerminalButton(
                      command: 'Add OpenCode Instance',
                      type: TerminalButtonType.primary,
                      onPressed: () => _showInstanceDialog(context, title: 'Add OpenCode Instance'),
                    ),
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildObsidianInstancesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Obsidian Instances (Notes)',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: OpenCodeTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<ObsidianInstanceBloc, ObsidianInstanceState>(
          builder: (context, state) {
            if (state is ObsidianInstancesLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: OpenCodeTheme.primary,
                ),
              );
            }

            if (state is ObsidianInstancesLoaded) {
              return Column(
                children: [
                  if (state.instances.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: OpenCodeTheme.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'No Obsidian instances saved',
                          style: TextStyle(
                            fontFamily: 'FiraCode',
                            fontSize: 14,
                            color: OpenCodeTheme.text.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    )
                  else
                    ...state.instances.map((instance) {
                      return InstanceListItem(
                        name: instance.name,
                        ip: instance.ip,
                        port: instance.port,
                        isConnected: _isObsidianCurrentlyConnected(instance),
                        onTap: () => _showEditObsidianInstanceDialog(context, instance),
                        onConnectionTap: () => _connectToObsidianInstance(instance),
                      );
                    }),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TerminalButton(
                      command: 'Add Obsidian Instance',
                      type: TerminalButtonType.primary,
                      onPressed: () => _showObsidianInstanceDialog(context, title: 'Add Obsidian Instance'),
                    ),
                  ),
                ],
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  bool _isCurrentlyConnected(OpenCodeInstance instance) {
    final configCubit = context.read<ConfigCubit>();
    final currentState = configCubit.state;

    if (currentState is ConfigLoaded) {
      return currentState.serverIp == instance.ip &&
             currentState.port.toString() == instance.port;
    }
    return false;
  }

  bool _isObsidianCurrentlyConnected(ObsidianInstance instance) {
    final connectionCubit = context.read<ObsidianConnectionCubit>();
    return connectionCubit.isInstanceActive(instance);
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

  void _showDeleteObsidianConfirmation(
      BuildContext context, ObsidianInstance instance) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: OpenCodeTheme.surface,
        title: const Text(
          'Delete Obsidian Instance',
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
              context.read<ObsidianInstanceBloc>().add(DeleteObsidianInstance(instance.id));
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
