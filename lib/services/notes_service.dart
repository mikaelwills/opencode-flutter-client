import 'dart:convert';
import 'dart:developer';
import 'package:dio/dio.dart';
import '../models/note.dart';

class NotesService {
  final Dio _dio;
  final String? baseUrl;
  final String? apiKey;
  final bool _isConfigured;

  NotesService({
    required this.baseUrl,
    required this.apiKey,
    Dio? dio,
  }) : _dio = dio ?? Dio(),
        _isConfigured = baseUrl != null && baseUrl.isNotEmpty &&
                       apiKey != null && apiKey.isNotEmpty {
    if (_isConfigured) {
      _dio.options.baseUrl = baseUrl!;
      _dio.options.headers['Authorization'] = 'Bearer $apiKey';
      _dio.options.headers['Content-Type'] = 'application/json';
      _dio.options.connectTimeout = const Duration(seconds: 10);
      _dio.options.receiveTimeout = const Duration(seconds: 30);
    }
  }

  /// Create an unconfigured service (no server connection)
  NotesService.unconfigured()
      : _dio = Dio(),
        baseUrl = null,
        apiKey = null,
        _isConfigured = false;

  /// Update service configuration when user connects to an Obsidian instance
  void updateConfiguration(String newBaseUrl, String newApiKey) {
    if (newBaseUrl.isNotEmpty && newApiKey.isNotEmpty) {
      _dio.options.baseUrl = newBaseUrl;
      _dio.options.headers['Authorization'] = 'Bearer $newApiKey';
      _dio.options.headers['Content-Type'] = 'application/json';
      _dio.options.connectTimeout = const Duration(seconds: 10);
      _dio.options.receiveTimeout = const Duration(seconds: 30);

      log('NotesService reconfigured with baseUrl: $newBaseUrl');
    }
  }

  /// Clear service configuration when user disconnects
  void clearConfiguration() {
    _dio.options.baseUrl = '';
    _dio.options.headers.remove('Authorization');
    log('NotesService configuration cleared');
  }

  Future<bool> isConfigured() async {
    return _dio.options.baseUrl.isNotEmpty &&
           _dio.options.headers['Authorization'] != null;
  }

  Future<bool> checkConnection() async {
    if (!(await isConfigured())) return false;

    try {
      final response = await _dio.get('/');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<NotesData> getNotesList() async {
    if (!(await isConfigured())) {
      log('NotesService not configured - cannot fetch notes list');
      return const NotesData(folders: [], notes: []);
    }

    try {
      final response = await _dio.get('/vault/');

      if (response.statusCode != 200) {
        log('Failed to fetch notes list: HTTP ${response.statusCode}');
        return const NotesData(folders: [], notes: []);
      }

      final data = response.data;
      if (data == null || data is! Map<String, dynamic>) {
        log('Invalid response format from notes list endpoint');
        return const NotesData(folders: [], notes: []);
      }

      final files = data['files'];
      if (files == null || files is! List) {
        log('No files array in notes list response');
        return const NotesData(folders: [], notes: []);
      }

      // Convert to List<String> and filter only relevant files
      final rootFiles = <String>[];
      final rootFolderPaths = <String>[];

      for (final file in files) {
        if (file is String) {
          if (file.endsWith('/')) {
            rootFolderPaths.add(file);
            rootFiles.add(file);
          } else if (file.endsWith('.md')) {
            rootFiles.add(file);
          }
        }
      }

      // Get contents of each folder and build all files list
      final allFiles = <String>[...rootFiles];
      for (final folderPath in rootFolderPaths) {
        try {
          final folderContents = await _getFolderContents(folderPath);
          allFiles.addAll(folderContents);
        } catch (e) {
          log('Error loading folder contents for "$folderPath": $e');
        }
      }

      // Create simple flat lists
      final folders = allFiles
          .where((file) => file.endsWith('/'))
          .map((path) => Folder.fromPath(path))
          .toList();

      final notes = allFiles
          .where((file) => file.endsWith('.md'))
          .map((path) => Note.fromPath(path))
          .toList();

      // Sort alphabetically
      folders.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      notes.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      return NotesData(
        folders: folders,
        notes: notes,
      );
    } catch (e) {
      log('Error loading notes list: $e');
      return const NotesData(folders: [], notes: []);
    }
  }

  Future<Note?> getNote(String path) async {
    if (!(await isConfigured())) {
      log('NotesService not configured - cannot fetch note: $path');
      return null;
    }

    try {
      final encodedPath = Uri.encodeComponent(path);
      final response = await _dio.get('/vault/$encodedPath');

      if (response.statusCode == 404) {
        log('Note not found: $path');
        return null;
      }

      if (response.statusCode != 200) {
        log('Failed to fetch note "$path": HTTP ${response.statusCode}');
        return null;
      }

      final data = response.data;
      if (data == null) {
        log('Server returned null data for note: $path');
        return null;
      }

      // Handle plain text response (raw markdown content)
      if (data is String) {
        final now = DateTime.now();
        final note = Note.fromPath(path).copyWith(
          content: data,
          size: data.length,
          createdTime: now,
          modifiedTime: now,
        );
        return note;
      }

      // Handle JSON response
      if (data is Map<String, dynamic>) {
        try {
          return Note.fromJson(data);
        } catch (e) {
          log('Failed to parse note JSON for "$path": $e');
          return null;
        }
      }

      log('Unexpected response format for note "$path": ${data.runtimeType}');
      return null;
    } catch (e) {
      log('Error loading note "$path": $e');
      return null;
    }
  }

  Future<bool> createNote(String path, String content) async {
    if (!(await isConfigured())) {
      log('NotesService not configured - cannot create note: $path');
      return false;
    }

    try {
      final encodedPath = Uri.encodeComponent(path);
      final url = '/vault/$encodedPath';

      log('Creating note: $path');

      final response = await _dio.post(
        url,
        data: content,
        options: Options(
          headers: {'Content-Type': 'text/markdown'},
        ),
      );

      log('Create response: HTTP ${response.statusCode}');

      if (response.statusCode == 409) {
        log('Note already exists: $path');
        return false;
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        log('Failed to create note "$path": HTTP ${response.statusCode}');
        return false;
      }

      log('Note created successfully: $path');
      return true;
    } catch (e) {
      log('Exception creating note "$path": $e');
      return false;
    }
  }

  Future<bool> updateNote(String path, String content) async {
    try {
      final encodedPath = Uri.encodeComponent(path);
      final url = '/vault/$encodedPath';

      log('Updating note: $path');
      final response = await _dio.put(
        url,
        data: content,
        options: Options(
          headers: {
            'Content-Type': 'text/markdown',  // As specified in docs
          },
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      log('Update response: HTTP ${response.statusCode}');

      if (response.statusCode == 404) {
        log('Note not found for update: $path');
        return false;
      }

      if (response.statusCode != 200 && response.statusCode != 204) {
        log('Failed to update note "$path": HTTP ${response.statusCode}');
        return false;
      }

      log('Note updated successfully: $path');
      return true;
    } catch (e) {
      log('Exception updating note "$path": $e');
      if (e is DioException) {
        log('   Dio error type: ${e.type}');
        log('   Dio error message: ${e.message}');
        log('   Response status: ${e.response?.statusCode}');
        log('   Response data: ${e.response?.data}');
      }
      return false;
    }
  }

  Future<bool> deleteNote(String path) async {
    try {
      final encodedPath = Uri.encodeComponent(path);
      final response = await _dio.delete('/vault/$encodedPath');

      if (response.statusCode == 404) {
        log('Note not found for deletion (already deleted?): $path');
        return true; // Idempotent - if already deleted, consider it success
      }

      if (response.statusCode != 200 && response.statusCode != 204) {
        log('Failed to delete note "$path": HTTP ${response.statusCode}');
        return false;
      }

      return true;
    } catch (e) {
      log('Error deleting note "$path": $e');
      return false;
    }
  }

  Future<bool> patchNote({
    required String path,
    required String content,
    int? position,
    String? heading,
  }) async {
    try {
      final encodedPath = Uri.encodeComponent(path);
      final patchData = <String, dynamic>{'content': content};

      if (position != null) {
        patchData['position'] = position;
      }

      if (heading != null) {
        patchData['heading'] = heading;
      }

      final response = await _dio.patch(
        '/vault/$encodedPath',
        data: jsonEncode(patchData),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 404) {
        log('Note not found for patch: $path');
        return false;
      }

      if (response.statusCode != 200) {
        log('Failed to patch note "$path": HTTP ${response.statusCode}');
        return false;
      }

      return true;
    } catch (e) {
      log('Error patching note "$path": $e');
      return false;
    }
  }

  Future<List<Note>> searchNotes(String query) async {
    try {
      final response = await _dio.get('/search/', queryParameters: {
        'query': query.trim(),
      });

      // Handle 404 as "no results found" instead of error
      if (response.statusCode == 404) {
        return [];
      }

      if (response.statusCode != 200) {
        log('Search service returned status ${response.statusCode} for query: $query');
        return [];
      }

      final data = response.data;
      if (data == null || data is! List) {
        return [];
      }

      final notes = <Note>[];
      for (final result in data) {
        try {
          if (result is String && result.endsWith('.md')) {
            notes.add(Note.fromPath(result));
          }
        } catch (e) {
          // Skip invalid results
        }
      }

      return notes;
    } on DioException catch (e) {
      // Handle 404 as empty results (no matches found)
      if (e.response?.statusCode == 404) {
        return [];
      }

      // Log and return empty for all other errors
      log('DioException during search for "$query": ${e.message}');
      return [];
    } catch (e) {
      // Log and return empty for any other unexpected errors
      log('Unexpected error during search for "$query": $e');
      return [];
    }
  }

  /// Get contents of a specific folder
  Future<List<String>> _getFolderContents(String folderPath) async {
    try {
      final encodedPath = Uri.encodeComponent(folderPath);
      final response = await _dio.get('/vault/$encodedPath');

      if (response.statusCode != 200) {
        log('Failed to fetch folder contents for "$folderPath": HTTP ${response.statusCode}');
        return [];
      }

      final data = response.data;
      if (data == null || data is! Map<String, dynamic>) {
        log('Invalid response format from folder contents endpoint for "$folderPath"');
        return [];
      }

      final files = data['files'];
      if (files == null || files is! List) {
        log('No files array in folder contents response for "$folderPath"');
        return [];
      }

      final folderContents = <String>[];
      for (final file in files) {
        if (file is String) {
          // Prepend the folder path to make it a full path
          final fullPath = '$folderPath$file';

          if (file.endsWith('/') || file.endsWith('.md')) {
            folderContents.add(fullPath);
          }
        }
      }

      return folderContents;
    } catch (e) {
      log('Error loading folder contents for "$folderPath": $e');
      return [];
    }
  }

}
