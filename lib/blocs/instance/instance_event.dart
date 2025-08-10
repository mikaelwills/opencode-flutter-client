import 'package:equatable/equatable.dart';
import '../../models/opencode_instance.dart';

abstract class InstanceEvent extends Equatable {
  const InstanceEvent();

  @override
  List<Object> get props => [];
}

class LoadInstances extends InstanceEvent {}

class AddInstance extends InstanceEvent {
  final OpenCodeInstance instance;

  const AddInstance(this.instance);

  @override
  List<Object> get props => [instance];
}

class UpdateInstance extends InstanceEvent {
  final OpenCodeInstance instance;

  const UpdateInstance(this.instance);

  @override
  List<Object> get props => [instance];
}

class DeleteInstance extends InstanceEvent {
  final String id;

  const DeleteInstance(this.id);

  @override
  List<Object> get props => [id];
}

class DeleteAllInstances extends InstanceEvent {}

class UpdateLastUsed extends InstanceEvent {
  final String id;

  const UpdateLastUsed(this.id);

  @override
  List<Object> get props => [id];
}