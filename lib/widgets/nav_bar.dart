import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../utils/session_validator.dart';
import '../theme/opencode_theme.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/session/session_bloc.dart';
import '../blocs/session/session_event.dart';
import '../blocs/instance/instance_bloc.dart';
import '../blocs/instance/instance_event.dart';
import '../models/opencode_instance.dart';
import 'terminal_button.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key});

  void _onNewSessionPressed(BuildContext context) {
    context.read<ChatBloc>().add(ClearChat());
    context.read<SessionBloc>().add(CreateSession());
  }

  void _showAddInstanceDialog(BuildContext context) {
    final nameController = TextEditingController();
    final ipController = TextEditingController();
    final portController = TextEditingController(text: '4096');
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
                          hintStyle: TextStyle(color: OpenCodeTheme.textSecondary),
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
                      flex: 3,
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
                          hintStyle: TextStyle(color: OpenCodeTheme.textSecondary),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      flex: 1,
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
                          hintStyle: TextStyle(color: OpenCodeTheme.textSecondary),
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
                TerminalButton(
                  command: 'cancel',
                  type: TerminalButtonType.neutral,
                  width: double.infinity,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                const SizedBox(height: 16),
                TerminalButton(
                  command: 'add',
                  type: TerminalButtonType.primary,
                  width: double.infinity,
                  onPressed: () {
                    if (formKey.currentState?.validate() ?? false) {
                      final now = DateTime.now();
                      final newInstance = OpenCodeInstance(
                        id: '',
                        name: nameController.text.trim(),
                        ip: ipController.text.trim(),
                        port: portController.text.trim(),
                        createdAt: now,
                        lastUsed: now,
                      );

                      context.read<InstanceBloc>().add(AddInstance(newInstance));
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
        children: [
          if (currentLocation == '/settings') ...[
            GestureDetector(
                onTap: () => SessionValidator.navigateToChat(context),
                child: const Icon(Icons.arrow_left, color: OpenCodeTheme.text)),
          ],
          if (currentLocation == '/sessions') ...[
            GestureDetector(
                onTap: () => SessionValidator.navigateToChat(context),
                child: const Icon(Icons.arrow_left, color: OpenCodeTheme.text)),
          ],
          if (currentLocation == '/provider-list') ...[
            GestureDetector(
                onTap: () => SessionValidator.navigateToChat(context),
                child: const Icon(Icons.arrow_left, color: OpenCodeTheme.text)),
          ],
          if (currentLocation == '/chat') ...[
            GestureDetector(
              onTap: () => context.go("/sessions"),
              child: const Icon(Icons.list_outlined, color: OpenCodeTheme.text),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () => _onNewSessionPressed(context),
              child: const Icon(Icons.create_outlined,
                  color: OpenCodeTheme.text),
            ),
          ],
          const Spacer(),
          if (currentLocation == '/settings') ...[
            GestureDetector(
              onTap: () => _showAddInstanceDialog(context),
              child: const Icon(Icons.add, color: OpenCodeTheme.text),
            ),
          ],
          if (currentLocation == '/chat' || currentLocation == '/sessions')
            GestureDetector(
                onTap: () => context.go("/settings"),
                child: const Icon(Icons.settings, color: OpenCodeTheme.text)),
        ],
      ),
    );
  }
}
