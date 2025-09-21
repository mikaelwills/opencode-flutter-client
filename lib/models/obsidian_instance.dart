import 'package:uuid/uuid.dart';

class ObsidianInstance {
  final String id;
  final String name;
  final String ip;
  final String port;
  final String apiKey;
  final DateTime createdAt;
  final DateTime lastUsed;

  ObsidianInstance({
    String? id,
    required this.name,
    required this.ip,
    required this.port,
    required this.apiKey,
    DateTime? createdAt,
    DateTime? lastUsed,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        lastUsed = lastUsed ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'apiKey': apiKey,
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed.toIso8601String(),
    };
  }

  factory ObsidianInstance.fromJson(Map<String, dynamic> json) {
    return ObsidianInstance(
      id: json['id'],
      name: json['name'],
      ip: json['ip'],
      port: json['port'],
      apiKey: json['apiKey'],
      createdAt: DateTime.parse(json['createdAt']),
      lastUsed: DateTime.parse(json['lastUsed']),
    );
  }

  ObsidianInstance copyWith({
    String? id,
    String? name,
    String? ip,
    String? port,
    String? apiKey,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return ObsidianInstance(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      apiKey: apiKey ?? this.apiKey,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ObsidianInstance && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ObsidianInstance(id: $id, name: $name, ip: $ip, port: $port)';
  }
}