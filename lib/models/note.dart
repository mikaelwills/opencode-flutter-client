import 'package:equatable/equatable.dart';

class Folder extends Equatable {
  final String path;
  final String name;
  final int depth;

  const Folder({
    required this.path,
    required this.name,
    required this.depth,
  });

  factory Folder.fromPath(String path) {
    // Calculate depth from path
    final cleanPath = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    final depth = cleanPath.isEmpty ? 0 : cleanPath.split('/').length - 1;

    // Extract folder name
    final name = cleanPath.split('/').last;

    return Folder(
      path: path,
      name: name,
      depth: depth,
    );
  }

  @override
  List<Object?> get props => [path, name, depth];

  Folder copyWith({
    String? path,
    String? name,
    int? depth,
  }) {
    return Folder(
      path: path ?? this.path,
      name: name ?? this.name,
      depth: depth ?? this.depth,
    );
  }
}

class Note extends Equatable {
  final String path;
  final String name;
  final String content;
  final String folderPath;
  final int depth;
  final Map<String, dynamic>? frontmatter;
  final int size;
  final DateTime createdTime;
  final DateTime modifiedTime;

  const Note({
    required this.path,
    required this.name,
    required this.content,
    required this.folderPath,
    required this.depth,
    this.frontmatter,
    required this.size,
    required this.createdTime,
    required this.modifiedTime,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    final path = json['path'] ?? '';
    return Note(
      path: path,
      name: _extractNoteName(path),
      content: json['content'] ?? '',
      folderPath: _extractFolderPath(path),
      depth: _calculateDepth(path),
      frontmatter: json['frontmatter'],
      size: json['size'] ?? 0,
      createdTime: DateTime.fromMillisecondsSinceEpoch(json['ctime'] ?? 0),
      modifiedTime: DateTime.fromMillisecondsSinceEpoch(json['mtime'] ?? 0),
    );
  }

  factory Note.fromPath(String path) {
    return Note(
      path: path,
      name: _extractNoteName(path),
      content: '',
      folderPath: _extractFolderPath(path),
      depth: _calculateDepth(path),
      size: 0,
      createdTime: DateTime.fromMillisecondsSinceEpoch(0),
      modifiedTime: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String _extractNoteName(String path) {
    final name = path.split('/').last;
    return name.replaceAll('.md', '');
  }

  static String _extractFolderPath(String path) {
    final parts = path.split('/');
    if (parts.length <= 1) return '';
    return '${parts.sublist(0, parts.length - 1).join('/')}/';
  }

  static int _calculateDepth(String path) {
    final folderPath = _extractFolderPath(path);
    if (folderPath.isEmpty) return 0;
    final cleanPath = folderPath.substring(0, folderPath.length - 1);
    return cleanPath.split('/').length;
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'name': name,
      'content': content,
      'folderPath': folderPath,
      'depth': depth,
      'frontmatter': frontmatter,
      'size': size,
      'ctime': createdTime.millisecondsSinceEpoch,
      'mtime': modifiedTime.millisecondsSinceEpoch,
    };
  }

  @override
  List<Object?> get props => [
        path,
        name,
        content,
        folderPath,
        depth,
        frontmatter,
        size,
        createdTime,
        modifiedTime,
      ];

  String get basename => path.split('/').last;

  Note copyWith({
    String? path,
    String? name,
    String? content,
    String? folderPath,
    int? depth,
    Map<String, dynamic>? frontmatter,
    int? size,
    DateTime? createdTime,
    DateTime? modifiedTime,
  }) {
    return Note(
      path: path ?? this.path,
      name: name ?? this.name,
      content: content ?? this.content,
      folderPath: folderPath ?? this.folderPath,
      depth: depth ?? this.depth,
      frontmatter: frontmatter ?? this.frontmatter,
      size: size ?? this.size,
      createdTime: createdTime ?? this.createdTime,
      modifiedTime: modifiedTime ?? this.modifiedTime,
    );
  }
}

class NotesData extends Equatable {
  final List<Folder> folders;
  final List<Note> notes;

  const NotesData({
    required this.folders,
    required this.notes,
  });

  @override
  List<Object?> get props => [folders, notes];

  NotesData copyWith({
    List<Folder>? folders,
    List<Note>? notes,
  }) {
    return NotesData(
      folders: folders ?? this.folders,
      notes: notes ?? this.notes,
    );
  }
}
