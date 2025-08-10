import 'package:equatable/equatable.dart';

class OpenCodeInstance extends Equatable {
  final String id;
  final String name;
  final String ip;
  final String port;
  final DateTime createdAt;
  final DateTime lastUsed;

  const OpenCodeInstance({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.createdAt,
    required this.lastUsed,
  });

  factory OpenCodeInstance.fromJson(Map<String, dynamic> json) {
    return OpenCodeInstance(
      id: json['id'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastUsed: DateTime.parse(json['lastUsed'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed.toIso8601String(),
    };
  }

  OpenCodeInstance copyWith({
    String? id,
    String? name,
    String? ip,
    String? port,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return OpenCodeInstance(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }

  String get displayAddress => '$ip:$port';

  @override
  List<Object?> get props => [id, name, ip, port, createdAt, lastUsed];

  @override
  String toString() {
    return 'OpenCodeInstance(id: $id, name: $name, ip: $ip, port: $port, createdAt: $createdAt, lastUsed: $lastUsed)';
  }
}