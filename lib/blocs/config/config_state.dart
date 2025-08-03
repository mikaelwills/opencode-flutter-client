import 'package:equatable/equatable.dart';

abstract class ConfigState extends Equatable {
  const ConfigState();

  @override
  List<Object?> get props => [];
}

class ConfigLoaded extends ConfigState {
  final String baseUrl;
  final String serverIp;
  final int port;

  const ConfigLoaded({
    required this.baseUrl,
    required this.serverIp,
    required this.port,
  });

  @override
  List<Object> get props => [baseUrl, serverIp, port];

  ConfigLoaded copyWith({
    String? baseUrl,
    String? serverIp,
    int? port,
  }) {
    return ConfigLoaded(
      baseUrl: baseUrl ?? this.baseUrl,
      serverIp: serverIp ?? this.serverIp,
      port: port ?? this.port,
    );
  }
}

class ConfigLoading extends ConfigState {}

class ConfigError extends ConfigState {
  final String message;

  const ConfigError(this.message);

  @override
  List<Object> get props => [message];
}