import 'package:equatable/equatable.dart';
import '../../models/obsidian_instance.dart';

abstract class ObsidianInstanceEvent extends Equatable {
  const ObsidianInstanceEvent();

  @override
  List<Object> get props => [];
}

class LoadObsidianInstances extends ObsidianInstanceEvent {}

class AddObsidianInstance extends ObsidianInstanceEvent {
  final ObsidianInstance instance;

  const AddObsidianInstance(this.instance);

  @override
  List<Object> get props => [instance];
}

class UpdateObsidianInstance extends ObsidianInstanceEvent {
  final ObsidianInstance instance;

  const UpdateObsidianInstance(this.instance);

  @override
  List<Object> get props => [instance];
}

class DeleteObsidianInstance extends ObsidianInstanceEvent {
  final String id;

  const DeleteObsidianInstance(this.id);

  @override
  List<Object> get props => [id];
}

class DeleteAllObsidianInstances extends ObsidianInstanceEvent {}

class UpdateObsidianLastUsed extends ObsidianInstanceEvent {
  final String id;

  const UpdateObsidianLastUsed(this.id);

  @override
  List<Object> get props => [id];
}