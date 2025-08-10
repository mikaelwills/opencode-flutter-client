import 'package:equatable/equatable.dart';
import '../../models/opencode_instance.dart';

abstract class InstanceState extends Equatable {
  const InstanceState();

  @override
  List<Object> get props => [];
}

class InstancesLoading extends InstanceState {}

class InstancesLoaded extends InstanceState {
  final List<OpenCodeInstance> instances;

  const InstancesLoaded(this.instances);

  @override
  List<Object> get props => [instances];

  InstancesLoaded copyWith({
    List<OpenCodeInstance>? instances,
  }) {
    return InstancesLoaded(
      instances ?? this.instances,
    );
  }
}

class InstanceError extends InstanceState {
  final String message;

  const InstanceError(this.message);

  @override
  List<Object> get props => [message];
}

class InstanceDeleting extends InstancesLoaded {
  final String deletingInstanceId;

  const InstanceDeleting({
    required List<OpenCodeInstance> instances,
    required this.deletingInstanceId,
  }) : super(instances);

  @override
  List<Object> get props => [instances, deletingInstanceId];
}