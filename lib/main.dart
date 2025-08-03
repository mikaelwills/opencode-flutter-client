import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

import 'theme/opencode_theme.dart';
import 'services/opencode_client.dart';
import 'services/sse_service.dart';
import 'blocs/connection/connection_bloc.dart';
import 'blocs/session/session_bloc.dart';
import 'blocs/session_list/session_list_bloc.dart';
import 'blocs/chat/chat_bloc.dart';
import 'blocs/config/config_cubit.dart';
import 'router/app_router.dart';
import 'config/opencode_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create and initialize ConfigCubit
  final configCubit = ConfigCubit();
  await configCubit.initialize();
  
  // Set the cubit for backward compatibility
  OpenCodeConfig.setConfigCubit(configCubit);

  final openCodeClient = OpenCodeClient();

  runApp(OpenCodeApp(
    openCodeClient: openCodeClient, 
    configCubit: configCubit,
  ));
}

class OpenCodeApp extends StatelessWidget {
  final OpenCodeClient openCodeClient;
  final ConfigCubit configCubit;

  const OpenCodeApp({
    super.key, 
    required this.openCodeClient,
    required this.configCubit,
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
          BlocProvider<SessionBloc>(
            create: (context) => SessionBloc(
              openCodeClient: context.read<OpenCodeClient>(),
            ),
          ),
          BlocProvider<SessionListBloc>(
            create: (context) => SessionListBloc(
              openCodeClient: context.read<OpenCodeClient>(),
            ),
          ),
          BlocProvider<ConnectionBloc>(
            create: (context) => ConnectionBloc(
              openCodeClient: context.read<OpenCodeClient>(),
              sessionBloc: context.read<SessionBloc>(),
            ),
          ),
          BlocProvider<ChatBloc>(
            create: (context) => ChatBloc(
              sessionBloc: context.read<SessionBloc>(),
              sseService: context.read<SSEService>(),
            ),
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


