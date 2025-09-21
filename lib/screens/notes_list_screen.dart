import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../theme/opencode_theme.dart';
import '../blocs/notes_bloc.dart';
import '../models/note.dart';
import '../widgets/note_list_item.dart';
import '../widgets/folder_list_item.dart';
import '../widgets/notes_search_bar.dart';
import '../widgets/mode_toggle_button.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    BlocProvider.of<NotesBloc>(context).add(LoadNotesList());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildNotesList(),
        _buildBottomInputArea(),
      ],
    );
  }

  Widget _buildBottomInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Semantics(
            label: 'Create new note',
            button: true,
            child: IconButton(
              onPressed: _showCreateNoteDialog,
              tooltip: 'Create new note',
              icon: const Icon(
                Icons.add,
                color: OpenCodeTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: NotesSearchBar(
              controller: _searchController,
              height: 30,
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(width: 8),
          const ModeToggleButton(isInNotes: true),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    return Expanded(
      child: BlocBuilder<NotesBloc, NotesState>(
        builder: (context, state) {
          if (state is NotesLoading) {
            return _buildLoadingState();
          }
          if (state is NotesError) {
            return _buildErrorState(state);
          }
          if (state is NotesListLoaded) {
            return _buildLoadedState(state);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(
          OpenCodeTheme.primary,
        ),
      ),
    );
  }

  Widget _buildErrorState(NotesError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: OpenCodeTheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            state.message,
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: OpenCodeTheme.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              BlocProvider.of<NotesBloc>(context).add(LoadNotesList());
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedState(NotesListLoaded state) {
    if (!state.isConnected) {
      return _buildConnectionErrorState();
    }

    // Filter notes based on search query
    final notesToShow = _filterNotes(state.notesData.notes, _searchQuery);

    // Handle empty search results
    if (_searchQuery.trim().length >= 1 && notesToShow.isEmpty) {
      return _buildNoSearchResultsState(_searchQuery);
    }

    // Handle general empty state
    if (notesToShow.isEmpty && state.notesData.folders.isEmpty) {
      return _buildEmptyState();
    }

    // Show filtered flat list during search, normal hierarchy otherwise
    if (_searchQuery.trim().length >= 1) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: notesToShow.length,
        itemBuilder: (context, index) {
          return _buildNoteItem(notesToShow[index]);
        },
      );
    } else {
      final items = _buildNotesAndFoldersList(state);
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: items,
      );
    }
  }

  Widget _buildConnectionErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: OpenCodeTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Cannot connect to Obsidian server',
            style: TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: OpenCodeTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              BlocProvider.of<NotesBloc>(context).add(LoadNotesList());
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.note_outlined,
            size: 48,
            color: OpenCodeTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No notes found',
            style: TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: OpenCodeTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _showCreateNoteDialog,
            child: const Text('Create first note'),
          ),
        ],
      ),
    );
  }


  Widget _buildNoSearchResultsState(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off_outlined,
            size: 48,
            color: OpenCodeTheme.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No results for "$query"',
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 14,
              color: OpenCodeTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(Note note) {
    return NoteListItem(
      key: ValueKey(note.path),
      note: note,
      onTap: () {
        final encodedPath = Uri.encodeComponent(note.path);
        context.go('/notes/$encodedPath');
      },
    );
  }

  List<Widget> _buildNotesAndFoldersList(NotesListLoaded state) {
    final List<Widget> items = [];

    // Add all folders with their nested notes
    for (final folder in state.notesData.folders) {
      items.add(_buildFolderItem(folder, state));

      // If expanded, add folder's notes
      if (state.expandedFolders.contains(folder.path)) {
        final folderNotes = _getFolderNotes(folder, state);
        items.addAll(folderNotes.map(_buildNoteItem));
      }
    }

    // Add root-level notes
    final rootNotes = _getRootNotes(state);
    items.addAll(rootNotes.map(_buildNoteItem));

    return items;
  }

  Widget _buildFolderItem(folder, NotesListLoaded state) {
    final isExpanded = state.expandedFolders.contains(folder.path);

    return FolderListItem(
      key: ValueKey(folder.path),
      folder: folder,
      isExpanded: isExpanded,
      onTap: () {
        BlocProvider.of<NotesBloc>(context)
            .add(ToggleFolderExpansion(folder.path));
      },
    );
  }

  List<Note> _getFolderNotes(folder, NotesListLoaded state) {
    return state.notesData.notes
        .where((note) => note.folderPath == folder.path)
        .toList();
  }

  List<Note> _getRootNotes(NotesListLoaded state) {
    return state.notesData.notes
        .where((note) => note.depth == 0)
        .toList();
  }

  List<Note> _filterNotes(List<Note> notes, String query) {
    if (query.trim().length < 1) return notes;

    final queryLower = query.toLowerCase();
    return notes.where((note) {
      return note.name.toLowerCase().contains(queryLower) ||
             note.path.toLowerCase().contains(queryLower);
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _showCreateNoteDialog() {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: OpenCodeTheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: OpenCodeTheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: const Text(
          'Create New Note',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: OpenCodeTheme.text,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 300,
            maxWidth: 400,
          ),
          child: Form(
            key: formKey,
            child: Container(
              height: 52,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: OpenCodeTheme.primary,
                    width: 2,
                  ),
                  right: BorderSide(
                    color: OpenCodeTheme.primary,
                    width: 2,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text(
                    '❯',
                    style: TextStyle(
                      fontFamily: 'FiraCode',
                      fontSize: 14,
                      color: OpenCodeTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: nameController,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (formKey.currentState?.validate() ?? false) {
                          final noteName = nameController.text.trim();
                          final notePath = '$noteName.md';
                          Navigator.of(dialogContext).pop();
                          if (mounted) {
                            context.go(
                                '/notes/${Uri.encodeComponent(notePath)}?new=true');
                          }
                        }
                      },
                      style: const TextStyle(
                        fontFamily: 'FiraCode',
                        fontSize: 14,
                        color: OpenCodeTheme.text,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        hintText: 'Note name (without .md)',
                        hintStyle:
                            TextStyle(color: OpenCodeTheme.textSecondary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Note name is required';
                        }
                        // Check for invalid characters
                        if (value.contains(RegExp(r'[<>:"/\|?*]'))) {
                          return 'Invalid characters in filename';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: OpenCodeTheme.textSecondary,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        final noteName = nameController.text.trim();
                        final notePath = '$noteName.md';
                        Navigator.of(dialogContext).pop();
                        if (mounted) {
                          context.go(
                              '/notes/edit/${Uri.encodeComponent(notePath)}?new=true');
                        }
                      }
                    },
                    child: const Text('Create'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).then((_) {
      // Dispose controller when dialog is closed
      nameController.dispose();
    });
  }
}