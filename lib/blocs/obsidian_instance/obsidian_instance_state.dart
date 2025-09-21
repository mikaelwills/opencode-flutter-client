import 'package:equatable/equatable.dart';
import '../../models/obsidian_instance.dart';

abstract class ObsidianInstanceState extends Equatable {
  const ObsidianInstanceState();

  @override
  List<Object> get props => [];
}

class ObsidianInstancesLoading extends ObsidianInstanceState {}

class ObsidianInstancesLoaded extends ObsidianInstanceState {
  final List<ObsidianInstance> instances;

  const ObsidianInstancesLoaded(this.instances);

  @override
  List<Object> get props => [instances];

  ObsidianInstancesLoaded copyWith({
    List<ObsidianInstance>? instances,
  }) {
    return ObsidianInstancesLoaded(
      instances ?? this.instances,
    );
  }
}

class ObsidianInstanceError extends ObsidianInstanceState {
  final String message;

  const ObsidianInstanceError(this.message);

  @override
  List<Object> get props => [message];
}

class ObsidianInstanceDeleting extends ObsidianInstancesLoaded {
  final String deletingInstanceId;

  const ObsidianInstanceDeleting({
    required List<ObsidianInstance> instances,
    required this.deletingInstanceId,
  }) : super(instances);

  @override
  List<Object> get props => [instances, deletingInstanceId];
}