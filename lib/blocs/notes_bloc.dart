import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../services/notes_service.dart';
import '../models/note.dart';
import 'obsidian_connection/obsidian_connection_cubit.dart';
import 'obsidian_connection/obsidian_connection_state.dart';

// Events
abstract class NotesEvent extends Equatable {
  const NotesEvent();

  @override
  List<Object?> get props => [];
}

class LoadNotesList extends NotesEvent {}

class LoadNote extends NotesEvent {
  final String path;

  const LoadNote(this.path);

  @override
  List<Object?> get props => [path];
}

class CreateNote extends NotesEvent {
  final String path;
  final String content;

  const CreateNote({
    required this.path,
    required this.content,
  });

  @override
  List<Object?> get props => [path, content];
}

class UpdateNote extends NotesEvent {
  final String path;
  final String content;

  const UpdateNote({
    required this.path,
    required this.content,
  });

  @override
  List<Object?> get props => [path, content];
}

class DeleteNote extends NotesEvent {
  final String path;

  const DeleteNote(this.path);

  @override
  List<Object?> get props => [path];
}

class SearchNotes extends NotesEvent {
  final String query;

  const SearchNotes(this.query);

  @override
  List<Object?> get props => [query];
}

class ClearSearch extends NotesEvent {}

class ToggleFolderExpansion extends NotesEvent {
  final String folderPath;

  const ToggleFolderExpansion(this.folderPath);

  @override
  List<Object?> get props => [folderPath];
}

class CheckConnection extends NotesEvent {}

class InitializeNotes extends NotesEvent {}

class PatchNote extends NotesEvent {
  final String path;
  final String content;
  final int? position;
  final String? heading;

  const PatchNote({
    required this.path,
    required this.content,
    this.position,
    this.heading,
  });

  @override
  List<Object?> get props => [path, content, position, heading];
}

// States
abstract class NotesState extends Equatable {
  const NotesState();

  @override
  List<Object?> get props => [];
}

class NotesInitial extends NotesState {}

class NotesLoading extends NotesState {}

class NotesListLoaded extends NotesState {
  final NotesData notesData;
  final bool isConnected;
  final String? searchQuery;
  final bool isSearchActive;
  final Set<String> expandedFolders;

  const NotesListLoaded({
    required this.notesData,
    this.isConnected = true,
    this.searchQuery,
    this.isSearchActive = false,
    this.expandedFolders = const {},
  });

  @override
  List<Object?> get props => [notesData, isConnected, searchQuery, isSearchActive, expandedFolders];

  NotesListLoaded copyWith({
    NotesData? notesData,
    bool? isConnected,
    String? searchQuery,
    bool? isSearchActive,
    Set<String>? expandedFolders,
  }) {
    return NotesListLoaded(
      notesData: notesData ?? this.notesData,
      isConnected: isConnected ?? this.isConnected,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearchActive: isSearchActive ?? this.isSearchActive,
      expandedFolders: expandedFolders ?? this.expandedFolders,
    );
  }

  NotesListLoaded copyWithNewNote(Note newNote) {
    final updatedNotes = [...notesData.notes, newNote];
    updatedNotes.sort((a, b) => a.path.compareTo(b.path));
    final updatedNotesData = notesData.copyWith(notes: updatedNotes);
    return copyWith(notesData: updatedNotesData);
  }

  NotesListLoaded copyWithRemovedNote(String path) {
    final updatedNotes = notesData.notes.where((note) => note.path != path).toList();
    final updatedNotesData = notesData.copyWith(notes: updatedNotes);
    return copyWith(notesData: updatedNotesData);
  }


  /// Calculate the indentation depth for an item based on its path
  static int calculateDepth(String path) {
    final cleanPath = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    if (cleanPath.isEmpty) return 0;
    return cleanPath.split('/').length - 1;
  }
}

class NoteLoaded extends NotesState {
  final Note note;

  const NoteLoaded(this.note);

  @override
  List<Object?> get props => [note];
}

class NotesSearchResults extends NotesState {
  final List<Note> searchResults;
  final String query;

  const NotesSearchResults({
    required this.searchResults,
    required this.query,
  });

  @override
  List<Object?> get props => [searchResults, query];
}

class NotesError extends NotesState {
  final String message;
  final bool isRetryable;

  const NotesError(this.message, {this.isRetryable = true});

  @override
  List<Object?> get props => [message, isRetryable];
}

class NoteCreated extends NotesState {
  final String path;

  const NoteCreated(this.path);

  @override
  List<Object?> get props => [path];
}

class NoteUpdated extends NotesState {
  final String path;

  const NoteUpdated(this.path);

  @override
  List<Object?> get props => [path];
}

class NoteDeleted extends NotesState {
  final String path;

  const NoteDeleted(this.path);

  @override
  List<Object?> get props => [path];
}

class NotesConnectionChecked extends NotesState {
  final bool isConnected;

  const NotesConnectionChecked(this.isConnected);

  @override
  List<Object?> get props => [isConnected];
}

class NotesInitializing extends NotesState {}

class NotesInitialized extends NotesState {
  final bool isConfigured;

  const NotesInitialized({required this.isConfigured});

  @override
  List<Object?> get props => [isConfigured];
}

class NotesConfigurationError extends NotesState {
  final String message;

  const NotesConfigurationError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class NotesBloc extends Bloc<NotesEvent, NotesState> {
  final NotesService _service;
  final ObsidianConnectionCubit _obsidianConnectionCubit;
  late StreamSubscription _obsidianConnectionSubscription;

  NotesBloc(this._service, this._obsidianConnectionCubit) : super(NotesInitial()) {
    // Load saved connection from SharedPreferences
    _obsidianConnectionCubit.loadSavedConnection();

    // Check initial connection state and configure service
    final initialState = _obsidianConnectionCubit.state;
    if (initialState is ObsidianConnectionLoaded &&
        initialState.baseUrl.isNotEmpty &&
        initialState.apiKey != null) {
      _service.updateConfiguration(initialState.baseUrl, initialState.apiKey!);
    }

    // Listen to ObsidianConnectionCubit changes and update NotesService configuration
    _obsidianConnectionSubscription = _obsidianConnectionCubit.stream.listen((connectionState) {
      if (connectionState is ObsidianConnectionLoaded) {
        if (connectionState.baseUrl.isNotEmpty && connectionState.apiKey != null) {
          // Configure notes service with the new connection
          _service.updateConfiguration(connectionState.baseUrl, connectionState.apiKey!);
        } else {
          // Clear configuration if not connected
          _service.clearConfiguration();
        }
      }
    });
    on<InitializeNotes>(_onInitializeNotes);
    on<CheckConnection>(_onCheckConnection);
    on<LoadNotesList>(_onLoadNotesList);
    on<LoadNote>(_onLoadNote);
    on<CreateNote>(_onCreateNote);
    on<UpdateNote>(_onUpdateNote);
    on<DeleteNote>(_onDeleteNote);
    on<PatchNote>(_onPatchNote);
    on<SearchNotes>(
      _onSearchNotes,
      transformer: (events, mapper) => events
          .debounceTime(const Duration(milliseconds: 300))
          .asyncExpand(mapper),
    );
    on<ClearSearch>(_onClearSearch);
    on<ToggleFolderExpansion>(_onToggleFolderExpansion);
  }


  Future<void> _onInitializeNotes(
    InitializeNotes event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesInitializing());

    try {
      final isConfigured = await _service.isConfigured();

      if (!isConfigured) {
        emit(const NotesConfigurationError(
          'Notes feature is not configured. Please set up your Obsidian API key in settings.',
        ));
        return;
      }

      emit(const NotesInitialized(isConfigured: true));
      add(LoadNotesList());
    } catch (e) {
      emit(NotesConfigurationError(
        'Failed to initialize notes: ${e.toString()}',
      ));
    }
  }

  Future<void> _onCheckConnection(
    CheckConnection event,
    Emitter<NotesState> emit,
  ) async {
    try {
      final isConnected = await _service.checkConnection();
      emit(NotesConnectionChecked(isConnected));
    } catch (e) {
      emit(const NotesConnectionChecked(false));
    }
  }

  Future<void> _onLoadNotesList(
    LoadNotesList event,
    Emitter<NotesState> emit,
  ) async {
    final currentState = state;

    // Preserve search state if we're currently in a search or list state
    String? currentSearchQuery;
    bool isSearchActive = false;

    if (currentState is NotesListLoaded) {
      currentSearchQuery = currentState.searchQuery;
      isSearchActive = currentState.isSearchActive;
    } else if (currentState is NotesSearchResults) {
      currentSearchQuery = currentState.query;
      isSearchActive = true;
    }

    emit(NotesLoading());

    try {
      final isConnected = await _service.checkConnection();

      if (!isConnected) {
        const emptyNotesData = NotesData(folders: [], notes: []);
        emit(NotesListLoaded(
          notesData: emptyNotesData,
          isConnected: false,
          searchQuery: currentSearchQuery,
          isSearchActive: isSearchActive,
        ));
        return;
      }

      final notesData = await _service.getNotesList();

      emit(NotesListLoaded(
        notesData: notesData,
        isConnected: true,
        searchQuery: currentSearchQuery,
        isSearchActive: isSearchActive,
      ));
    } catch (e) {
      emit(NotesError(e.toString()));
    }
  }

  Future<void> _onLoadNote(
    LoadNote event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesLoading());

    final note = await _service.getNote(event.path);
    if (note != null) {
      emit(NoteLoaded(note));
    } else {
      emit(const NotesError('Note not found or could not be loaded.'));
    }
  }

  Future<void> _onCreateNote(
    CreateNote event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesLoading());

    final success = await _service.createNote(event.path, event.content);

    if (success) {
      emit(NoteCreated(event.path));
      add(LoadNotesList());
    } else {
      emit(const NotesError('Could not create note. It may already exist or there was a connection error.'));
    }
  }

  Future<void> _onUpdateNote(
    UpdateNote event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesLoading());

    final success = await _service.updateNote(event.path, event.content);

    if (success) {
      emit(NoteUpdated(event.path));
    } else {
      emit(const NotesError('Could not save changes. The Obsidian REST API plugin may not support write operations. Please check the plugin configuration or try a different REST API plugin.'));
    }
  }

  Future<void> _onDeleteNote(
    DeleteNote event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesLoading());

    final success = await _service.deleteNote(event.path);
    if (success) {
      emit(NoteDeleted(event.path));
      add(LoadNotesList());
    } else {
      emit(const NotesError('Could not delete note. There may have been a connection error.'));
    }
  }

  Future<void> _onPatchNote(
    PatchNote event,
    Emitter<NotesState> emit,
  ) async {
    emit(NotesLoading());

    final success = await _service.patchNote(
      path: event.path,
      content: event.content,
      position: event.position,
      heading: event.heading,
    );

    if (success) {
      emit(NoteUpdated(event.path));
    } else {
      emit(const NotesError('Could not update note. The note may no longer exist or there was a connection error.'));
    }
  }

  Future<void> _onSearchNotes(
    SearchNotes event,
    Emitter<NotesState> emit,
  ) async {
    if (event.query.trim().isEmpty) {
      add(LoadNotesList());
      return;
    }

    emit(NotesLoading());

    try {
      final results = await _service.searchNotes(event.query);
      emit(NotesSearchResults(searchResults: results, query: event.query));
    } on DioException catch (e) {
      // Handle specific HTTP errors gracefully
      if (e.response?.statusCode == 404) {
        // 404 should have been handled by service, but just in case
        emit(NotesSearchResults(searchResults: const [], query: event.query));
      } else if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        emit(const NotesError('Authentication failed. Please check your API key in settings.'));
      } else if (e.type == DioExceptionType.connectionTimeout ||
                 e.type == DioExceptionType.receiveTimeout ||
                 e.type == DioExceptionType.connectionError) {
        emit(const NotesError('Connection error. Please check your network and server settings.'));
      } else if (e.response?.statusCode != null && e.response!.statusCode! >= 500) {
        emit(const NotesError('Server error. Please try again later.'));
      } else {
        emit(NotesError('Search failed: ${e.message ?? 'Unknown error'}'));
      }
    } catch (e) {
      emit(NotesError('Unexpected error during search: ${e.toString()}'));
    }
  }

  Future<void> _onClearSearch(
    ClearSearch event,
    Emitter<NotesState> emit,
  ) async {
    add(LoadNotesList());
  }

  void _onToggleFolderExpansion(
    ToggleFolderExpansion event,
    Emitter<NotesState> emit,
  ) {
    final currentState = state;

    if (currentState is NotesListLoaded) {
      final expandedFolders = Set<String>.from(currentState.expandedFolders);

      if (expandedFolders.contains(event.folderPath)) {
        expandedFolders.remove(event.folderPath);
      } else {
        expandedFolders.add(event.folderPath);
      }

      final newState = currentState.copyWith(expandedFolders: expandedFolders);

      emit(newState);
    }
  }

  @override
  Future<void> close() {
    _obsidianConnectionSubscription.cancel();
    return super.close();
  }
}
