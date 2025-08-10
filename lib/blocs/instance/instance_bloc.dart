import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../models/opencode_instance.dart';
import 'instance_event.dart';
import 'instance_state.dart';

class InstanceBloc extends Bloc<InstanceEvent, InstanceState> {
  static const String _storageKey = 'opencode_instances';
  final _uuid = const Uuid();

  InstanceBloc() : super(InstancesLoading()) {
    on<LoadInstances>(_onLoadInstances);
    on<AddInstance>(_onAddInstance);
    on<UpdateInstance>(_onUpdateInstance);
    on<DeleteInstance>(_onDeleteInstance);
    on<DeleteAllInstances>(_onDeleteAllInstances);
    on<UpdateLastUsed>(_onUpdateLastUsed);
  }

  Future<void> _onLoadInstances(LoadInstances event, Emitter<InstanceState> emit) async {
    try {
      emit(InstancesLoading());
      final instances = await _loadInstancesFromStorage();
      emit(InstancesLoaded(instances));
    } catch (e) {
      emit(InstanceError('Failed to load instances: ${e.toString()}'));
    }
  }

  Future<void> _onAddInstance(AddInstance event, Emitter<InstanceState> emit) async {
    try {
      final currentState = state;
      if (currentState is! InstancesLoaded) {
        emit(const InstanceError('Cannot add instance when instances are not loaded'));
        return;
      }

      // Check if instance with same name already exists
      final existingInstance = currentState.instances.firstWhere(
        (instance) => instance.name.toLowerCase() == event.instance.name.toLowerCase(),
        orElse: () => OpenCodeInstance(
          id: '',
          name: '',
          ip: '',
          port: '',
          createdAt: DateTime.now(),
          lastUsed: DateTime.now(),
        ),
      );

      if (existingInstance.id.isNotEmpty) {
        emit(InstanceError('An instance with the name "${event.instance.name}" already exists'));
        return;
      }

      final newInstance = event.instance.copyWith(
        id: event.instance.id.isEmpty ? _uuid.v4() : event.instance.id,
      );

      final updatedInstances = [...currentState.instances, newInstance];
      await _saveInstancesToStorage(updatedInstances);
      emit(InstancesLoaded(updatedInstances));
    } catch (e) {
      emit(InstanceError('Failed to add instance: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateInstance(UpdateInstance event, Emitter<InstanceState> emit) async {
    try {
      final currentState = state;
      if (currentState is! InstancesLoaded) {
        emit(const InstanceError('Cannot update instance when instances are not loaded'));
        return;
      }

      final updatedInstances = currentState.instances.map((instance) {
        if (instance.id == event.instance.id) {
          return event.instance;
        }
        return instance;
      }).toList();

      await _saveInstancesToStorage(updatedInstances);
      emit(InstancesLoaded(updatedInstances));
    } catch (e) {
      emit(InstanceError('Failed to update instance: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteInstance(DeleteInstance event, Emitter<InstanceState> emit) async {
    try {
      final currentState = state;
      if (currentState is! InstancesLoaded) {
        emit(const InstanceError('Cannot delete instance when instances are not loaded'));
        return;
      }

      // Show deleting state
      emit(InstanceDeleting(
        instances: currentState.instances,
        deletingInstanceId: event.id,
      ));

      // Simulate deletion delay for UX
      await Future.delayed(const Duration(milliseconds: 500));

      final updatedInstances = currentState.instances
          .where((instance) => instance.id != event.id)
          .toList();

      await _saveInstancesToStorage(updatedInstances);
      emit(InstancesLoaded(updatedInstances));
    } catch (e) {
      emit(InstanceError('Failed to delete instance: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteAllInstances(DeleteAllInstances event, Emitter<InstanceState> emit) async {
    try {
      await _saveInstancesToStorage([]);
      emit(const InstancesLoaded([]));
    } catch (e) {
      emit(InstanceError('Failed to delete all instances: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateLastUsed(UpdateLastUsed event, Emitter<InstanceState> emit) async {
    try {
      final currentState = state;
      if (currentState is! InstancesLoaded) return;

      final updatedInstances = currentState.instances.map((instance) {
        if (instance.id == event.id) {
          return instance.copyWith(lastUsed: DateTime.now());
        }
        return instance;
      }).toList();

      await _saveInstancesToStorage(updatedInstances);
      emit(InstancesLoaded(updatedInstances));
    } catch (e) {
      // Silently fail for lastUsed updates to not disrupt user flow
      print('Failed to update last used: ${e.toString()}');
    }
  }

  Future<List<OpenCodeInstance>> _loadInstancesFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instancesJson = prefs.getString(_storageKey);
      
      if (instancesJson == null || instancesJson.isEmpty) {
        return [];
      }

      final List<dynamic> instancesList = json.decode(instancesJson);
      return instancesList
          .map((json) => OpenCodeInstance.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load instances from storage: ${e.toString()}');
    }
  }

  Future<void> _saveInstancesToStorage(List<OpenCodeInstance> instances) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instancesJson = json.encode(instances.map((instance) => instance.toJson()).toList());
      await prefs.setString(_storageKey, instancesJson);
    } catch (e) {
      throw Exception('Failed to save instances to storage: ${e.toString()}');
    }
  }
}