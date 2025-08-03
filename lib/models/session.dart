import 'package:equatable/equatable.dart';

class Session extends Equatable {
  final String id;
  final DateTime created;
  final DateTime? lastActivity;
  final bool isActive;

  const Session({
    required this.id,
    required this.created,
    this.lastActivity,
    this.isActive = false,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    print("🍕 created: $json['created']");
    return Session(
      id: json['id'] as String,
      created:
          DateTime.fromMillisecondsSinceEpoch(json['time']['created'] as int),
      lastActivity: json['lastActivity'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastActivity'] as int)
          : null,
      isActive: json['isActive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created': created.toIso8601String(),
      'lastActivity': lastActivity?.toIso8601String(),
      'isActive': isActive,
    };
  }

  Session copyWith({
    String? id,
    DateTime? created,
    DateTime? lastActivity,
    bool? isActive,
  }) {
    return Session(
      id: id ?? this.id,
      created: created ?? this.created,
      lastActivity: lastActivity ?? this.lastActivity,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [id, created, lastActivity, isActive];
}

