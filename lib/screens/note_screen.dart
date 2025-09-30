import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import '../theme/opencode_theme.dart';
import '../blocs/notes_bloc.dart';
import '../widgets/markdown_styles.dart';

class NoteScreen extends StatefulWidget {
  final String notePath;
  final bool isNewNote;

  const NoteScreen({
    super.key,
    required this.notePath,
    this.isNewNote = false,
  });

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  late TextEditingController _contentController;
  bool _hasUnsavedChanges = false;
  String _originalContent = '';
  bool _hasLoadedInitialContent = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _contentController.addListener(_onContentChanged);

    if (!widget.isNewNote) {
      BlocProvider.of<NotesBloc>(context).add(LoadNote(widget.notePath));
    } else {
      _contentController.text = '# ${_getFileName()}\n\n';
      _originalContent = _contentController.text;
      _hasLoadedInitialContent = true;
      _isEditing = true; // New notes start in edit mode
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (await _onWillPop()) {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Column(
        children: [
          Expanded(child: _buildContent()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
      children: [
        Semantics(
          label: 'Go back to notes list',
          button: true,
          child: IconButton(
            onPressed: () async {
              final navigator = context;
              final shouldPop = await _onWillPop();
              if (!shouldPop) return;
              if (!navigator.mounted) return;
              navigator.go('/notes');
            },
            tooltip: 'Back to notes',
            icon: const Icon(
              Icons.arrow_back,
              color: OpenCodeTheme.text,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _getFileNameWithExtension(),
            style: const TextStyle(
              fontFamily: 'FiraCode',
              fontSize: 18,
              color: OpenCodeTheme.text,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (_isEditing && _hasUnsavedChanges) ...[
          Semantics(
            label: 'Save note',
            button: true,
            child: IconButton(
              onPressed: _saveNote,
              tooltip: 'Save changes',
              icon: const Icon(
                Icons.check,
                color: OpenCodeTheme.success,
              ),
            ),
          ),
        ],
        if (!widget.isNewNote)
          Semantics(
            label: 'Delete note',
            button: true,
            child: IconButton(
              onPressed: _showDeleteConfirmation,
              tooltip: 'Delete note',
              icon: const Icon(
                Icons.delete_outline,
                color: OpenCodeTheme.error,
              ),
            ),
          ),
      ],
      ),
    );
  }

  Widget _buildPreview() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isEditing = true;
        });
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
        child: _contentController.text.isEmpty
            ? const Text(
                'Tap to start writing...',
                style: TextStyle(
                  fontFamily: 'FiraCode',
                  fontSize: 14,
                  color: OpenCodeTheme.textSecondary,
                ),
              )
            : Markdown(
                data: _contentController.text,
                styleSheet: OpenCodeMarkdownStyles.standard,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
              ),
      ),
    );
  }

  Widget _buildEditor() {
    return TextField(
      controller: _contentController,
      style: const TextStyle(
        fontFamily: 'FiraCode',
        fontSize: 14,
        color: OpenCodeTheme.text,
        height: 1.6,
      ),
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: false,
        hintText: 'Start writing your note...',
        hintStyle: TextStyle(
          color: OpenCodeTheme.textSecondary,
        ),
        contentPadding: EdgeInsets.only(left: 16, bottom: 16),
      ),
    );
  }

  Widget _buildContent() {
    return BlocListener<NotesBloc, NotesState>(
        listener: (context, state) {
          if (state is NoteCreated || state is NoteUpdated) {
            // Update state safely after successful save
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _hasUnsavedChanges = false;
                  _originalContent = _contentController.text;
                  _isEditing = false; // Return to preview mode after save
                  // Ensure we don't reset content after successful save
                  if (!_hasLoadedInitialContent) {
                    _hasLoadedInitialContent = true;
                  }
                });
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.isNewNote ? 'Note created' : 'Note saved',
                  style: const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 14,
                  ),
                ),
                backgroundColor: OpenCodeTheme.success,
              ),
            );
          }

          if (state is NoteDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Note deleted: ${_getFileName()}',
                  style: const TextStyle(
                    fontFamily: 'FiraCode',
                    fontSize: 14,
                  ),
                ),
                backgroundColor: OpenCodeTheme.success,
              ),
            );
            context.go('/notes');
          }
        },
        child: BlocBuilder<NotesBloc, NotesState>(
          builder: (context, state) {
            if (state is NotesLoading && !widget.isNewNote) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    OpenCodeTheme.primary,
                  ),
                ),
              );
            }

            if (state is NotesError) {
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
                        if (!widget.isNewNote) {
                          BlocProvider.of<NotesBloc>(context)
                              .add(LoadNote(widget.notePath));
                        }
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (state is NoteLoaded && !widget.isNewNote && !_hasLoadedInitialContent) {
              // Only set content on initial load, not during editing
              // Temporarily disable listener to prevent setState() during build
              _contentController.removeListener(_onContentChanged);
              _contentController.text = state.note.content;
              _originalContent = state.note.content;
              _hasUnsavedChanges = false;
              _hasLoadedInitialContent = true;

              // Re-enable listener after build completes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _contentController.addListener(_onContentChanged);
              });
            }

            return _isEditing ? _buildEditor() : _buildPreview();
          },
        ),
    );
  }

  void _onContentChanged() {
    final hasChanges = _contentController.text != _originalContent;
    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  void _saveNote() {
    final content = _contentController.text;

    if (widget.isNewNote) {
      BlocProvider.of<NotesBloc>(context).add(
        CreateNote(path: widget.notePath, content: content),
      );
    } else {
      BlocProvider.of<NotesBloc>(context).add(
        UpdateNote(path: widget.notePath, content: content),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: OpenCodeTheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: OpenCodeTheme.warning.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: const Text(
          'Unsaved Changes',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: OpenCodeTheme.warning,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave without saving?',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 14,
            color: OpenCodeTheme.text,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: OpenCodeTheme.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: OpenCodeTheme.warning,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: OpenCodeTheme.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: OpenCodeTheme.error.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: const Text(
          'Delete Note',
          style: TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 16,
            color: OpenCodeTheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${_getFileName()}"? This action cannot be undone.',
          style: const TextStyle(
            fontFamily: 'FiraCode',
            fontSize: 14,
            color: OpenCodeTheme.text,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(
              foregroundColor: OpenCodeTheme.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              BlocProvider.of<NotesBloc>(context)
                  .add(DeleteNote(widget.notePath));
            },
            style: TextButton.styleFrom(
              foregroundColor: OpenCodeTheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _getFileName() {
    return widget.notePath.split('/').last.replaceAll('.md', '');
  }

  String _getFileNameWithExtension() {
    return widget.notePath.split('/').last;
  }
}
