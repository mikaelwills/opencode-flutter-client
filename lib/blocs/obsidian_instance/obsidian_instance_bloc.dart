import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/obsidian_instance.dart';
import 'obsidian_instance_event.dart';
import 'obsidian_instance_state.dart';

class ObsidianInstanceBloc extends Bloc<ObsidianInstanceEvent, ObsidianInstanceState> {
  static const String _storageKey = 'obsidian_instances';
  final _uuid = const Uuid();

  ObsidianInstanceBloc() : super(ObsidianInstancesLoading()) {
    on<LoadObsidianInstances>(_onLoadObsidianInstances);
    on<AddObsidianInstance>(_onAddObsidianInstance);
    on<UpdateObsidianInstance>(_onUpdateObsidianInstance);
    on<DeleteObsidianInstance>(_onDeleteObsidianInstance);
    on<DeleteAllObsidianInstances>(_onDeleteAllObsidianInstances);
    on<UpdateObsidianLastUsed>(_onUpdateObsidianLastUsed);
  }

  Future<void> _onLoadObsidianInstances(LoadObsidianInstances event, Emitter<ObsidianInstanceState> emit) async {
    try {
      emit(ObsidianInstancesLoading());
      final instances = await _loadInstancesFromStorage();
      emit(ObsidianInstancesLoaded(instances));
    } catch (e) {
      emit(ObsidianInstanceError('Failed to load instances: ${e.toString()}'));
    }
  }

  Future<void> _onAddObsidianInstance(AddObsidianInstance event, Emitter<ObsidianInstanceState> emit) async {
    try {
      final currentState = state;
      if (currentState is! ObsidianInstancesLoaded) {
        emit(const ObsidianInstanceError('Cannot add instance when instances are not loaded'));
        return;
      }

      // Check if instance with same name already exists
      final existingInstance = currentState.instances.firstWhere(
        (instance) => instance.name.toLowerCase() == event.instance.name.toLowerCase(),
        orElse: () => ObsidianInstance(
          id: '',
          name: '',
          ip: '',
          port: '',
          apiKey: '',
          createdAt: DateTime.now(),
          lastUsed: DateTime.now(),
        ),
      );

      if (existingInstance.id.isNotEmpty) {
        emit(ObsidianInstanceError('An instance with the name "${event.instance.name}" already exists'));
        return;
      }

      final newInstance = event.instance.copyWith(
        id: event.instance.id.isEmpty ? _uuid.v4() : event.instance.id,
      );

      final updatedInstances = [...currentState.instances, newInstance];
      await _saveInstancesToStorage(updatedInstances);
      emit(ObsidianInstancesLoaded(updatedInstances));
    } catch (e) {
      emit(ObsidianInstanceError('Failed to add instance: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateObsidianInstance(UpdateObsidianInstance event, Emitter<ObsidianInstanceState> emit) async {
    try {
      final currentState = state;
      if (currentState is! ObsidianInstancesLoaded) {
        emit(const ObsidianInstanceError('Cannot update instance when instances are not loaded'));
        return;
      }

      final updatedInstances = currentState.instances.map((instance) {
        if (instance.id == event.instance.id) {
          return event.instance;
        }
        return instance;
      }).toList();

      await _saveInstancesToStorage(updatedInstances);
      emit(ObsidianInstancesLoaded(updatedInstances));
    } catch (e) {
      emit(ObsidianInstanceError('Failed to update instance: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteObsidianInstance(DeleteObsidianInstance event, Emitter<ObsidianInstanceState> emit) async {
    try {
      final currentState = state;
      if (currentState is! ObsidianInstancesLoaded) {
        emit(const ObsidianInstanceError('Cannot delete instance when instances are not loaded'));
        return;
      }

      // Show deleting state
      emit(ObsidianInstanceDeleting(
        instances: currentState.instances,
        deletingInstanceId: event.id,
      ));

      // Simulate deletion delay for UX
      await Future.delayed(const Duration(milliseconds: 500));

      final updatedInstances = currentState.instances
          .where((instance) => instance.id != event.id)
          .toList();

      await _saveInstancesToStorage(updatedInstances);
      emit(ObsidianInstancesLoaded(updatedInstances));
    } catch (e) {
      emit(ObsidianInstanceError('Failed to delete instance: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteAllObsidianInstances(DeleteAllObsidianInstances event, Emitter<ObsidianInstanceState> emit) async {
    try {
      await _saveInstancesToStorage([]);
      emit(const ObsidianInstancesLoaded([]));
    } catch (e) {
      emit(ObsidianInstanceError('Failed to delete all instances: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateObsidianLastUsed(UpdateObsidianLastUsed event, Emitter<ObsidianInstanceState> emit) async {
    try {
      final currentState = state;
      if (currentState is! ObsidianInstancesLoaded) return;

      final updatedInstances = currentState.instances.map((instance) {
        if (instance.id == event.id) {
          return instance.copyWith(lastUsed: DateTime.now());
        }
        return instance;
      }).toList();

      await _saveInstancesToStorage(updatedInstances);
      emit(ObsidianInstancesLoaded(updatedInstances));
    } catch (e) {
      // Silently fail for lastUsed updates to not disrupt user flow
      print('Failed to update last used: ${e.toString()}');
    }
  }

  Future<List<ObsidianInstance>> _loadInstancesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instancesJson = prefs.getString(_storageKey);

      if (instancesJson == null || instancesJson.isEmpty) {
        return [];
      }

      final List<dynamic> instancesList = json.decode(instancesJson);
      return instancesList
          .map((json) => ObsidianInstance.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load instances from storage: ${e.toString()}');
    }
  }

  Future<void> _saveInstancesToStorage(List<ObsidianInstance> instances) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instancesJson = json.encode(instances.map((instance) => instance.toJson()).toList());
      await prefs.setString(_storageKey, instancesJson);
    } catch (e) {
      throw Exception('Failed to save instances to storage: ${e.toString()}');
    }
  }
}