import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'theme/opencode_theme.dart';
import 'services/opencode_client.dart';
import 'services/sse_service.dart';
import 'services/message_queue_service.dart';
import 'blocs/connection/connection_bloc.dart';
import 'blocs/session/session_bloc.dart';
import 'blocs/session/session_event.dart';
import 'blocs/session_list/session_list_bloc.dart';
import 'blocs/chat/chat_bloc.dart';
import 'blocs/config/config_cubit.dart';
import 'blocs/config/config_state.dart';
import 'blocs/instance/instance_bloc.dart';
import 'blocs/obsidian_instance/obsidian_instance_bloc.dart';
import 'blocs/obsidian_connection/obsidian_connection_cubit.dart';
import 'blocs/notes_bloc.dart';
import 'services/notes_service.dart';
import 'router/app_router.dart';
import 'config/opencode_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create and initialize ConfigCubit
  final configCubit = ConfigCubit();
  await configCubit.initialize();

  // Set the cubit for backward compatibility
  OpenCodeConfig.setConfigCubit(configCubit);

  // Create unconfigured NotesService initially - it will be updated when user connects to an Obsidian instance
  final notesService = NotesService.unconfigured();

  final openCodeClient = OpenCodeClient();

  // Apply saved provider/model settings if available
  final configState = configCubit.state;
  if (configState is ConfigLoaded &&
      configState.selectedProviderID != null &&
      configState.selectedModelID != null) {
    openCodeClient.setProvider(
        configState.selectedProviderID!, configState.selectedModelID!);
  }

  // Create SessionBloc and initialize with stored session
  final sessionBloc = SessionBloc(openCodeClient: openCodeClient);
  sessionBloc.add(LoadStoredSession());

  runApp(OpenCodeApp(
    openCodeClient: openCodeClient,
    configCubit: configCubit,
    sessionBloc: sessionBloc,
    notesService: notesService,
  ));
}

class OpenCodeApp extends StatelessWidget {
  final OpenCodeClient openCodeClient;
  final ConfigCubit configCubit;
  final SessionBloc sessionBloc;
  final NotesService notesService;

  const OpenCodeApp({
    super.key,
    required this.openCodeClient,
    required this.configCubit,
    required this.sessionBloc,
    required this.notesService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<OpenCodeClient>.value(value: openCodeClient),
        Provider<SSEService>(create: (_) => SSEService()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ConfigCubit>.value(value: configCubit),
          BlocProvider<SessionBloc>.value(value: sessionBloc),
          BlocProvider<SessionListBloc>(
            create: (context) => SessionListBloc(
              openCodeClient: context.read<OpenCodeClient>(),
            ),
          ),
          BlocProvider<ConnectionBloc>(
            create: (context) => ConnectionBloc(
              openCodeClient: context.read<OpenCodeClient>(),
              sessionBloc: sessionBloc,
            ),
          ),
          Provider<MessageQueueService>(
            create: (context) => MessageQueueService(
              connectionBloc: context.read<ConnectionBloc>(),
              sessionBloc: sessionBloc,
            ),
          ),
          BlocProvider<ChatBloc>(
            create: (context) {
              final chatBloc = ChatBloc(
                sessionBloc: sessionBloc,
                sseService: context.read<SSEService>(),
                openCodeClient: context.read<OpenCodeClient>(),
                messageQueueService: context.read<MessageQueueService>(),
              );

              // Initialize the MessageQueueService's ChatBloc listener
              context
                  .read<MessageQueueService>()
                  .initChatBlocListener(chatBloc);

              return chatBloc;
            },
          ),
          BlocProvider<InstanceBloc>(
            create: (context) => InstanceBloc(),
          ),
          BlocProvider<ObsidianInstanceBloc>(
            create: (context) => ObsidianInstanceBloc(),
          ),
          BlocProvider<ObsidianConnectionCubit>(
            create: (context) => ObsidianConnectionCubit(),
          ),
          BlocProvider<NotesBloc>(
            create: (context) {
              final obsidianConnectionCubit = context.read<ObsidianConnectionCubit>();
              final notesBloc = NotesBloc(notesService, obsidianConnectionCubit);
              notesBloc.add(InitializeNotes());
              return notesBloc;
            },
          ),
        ],
        child: Container(
          color: OpenCodeTheme.background,
          child: SafeArea(
            child: MaterialApp.router(
              title: 'OpenCode Mobile',
              theme: OpenCodeTheme.themeData,
              routerConfig: appRouter,
              debugShowCheckedModeBanner: false,
            ),
          ),
        ),
      ),
    );
  }
}
