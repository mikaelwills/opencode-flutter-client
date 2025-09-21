import 'package:equatable/equatable.dart';
import '../../models/obsidian_instance.dart';

abstract class ObsidianConnectionState extends Equatable {
  const ObsidianConnectionState();

  @override
  List<Object?> get props => [];
}

class ObsidianConnectionLoading extends ObsidianConnectionState {}

class ObsidianConnectionLoaded extends ObsidianConnectionState {
  final ObsidianInstance? activeInstance;
  final String baseUrl;
  final String? apiKey;

  const ObsidianConnectionLoaded({
    required this.activeInstance,
    required this.baseUrl,
    this.apiKey,
  });

  @override
  List<Object?> get props => [activeInstance, baseUrl, apiKey];

  ObsidianConnectionLoaded copyWith({
    ObsidianInstance? activeInstance,
    String? baseUrl,
    String? apiKey,
  }) {
    return ObsidianConnectionLoaded(
      activeInstance: activeInstance ?? this.activeInstance,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  bool get hasActiveConnection => activeInstance != null && apiKey != null;
}

class ObsidianConnectionError extends ObsidianConnectionState {
  final String message;

  const ObsidianConnectionError(this.message);

  @override
  List<Object> get props => [message];
}