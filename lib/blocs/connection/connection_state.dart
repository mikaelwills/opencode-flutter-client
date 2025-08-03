import 'package:equatable/equatable.dart';

abstract class ConnectionState extends Equatable {
  const ConnectionState();

  @override
  List<Object> get props => [];
}

class ConnectionInitial extends ConnectionState {}


class ConnectedWithSession extends ConnectionState {
  final String sessionId;

  const ConnectedWithSession({required this.sessionId});

  @override
  List<Object> get props => [sessionId];
}

class Disconnected extends ConnectionState {
  final String? reason;

  const Disconnected({this.reason});

  @override
  List<Object> get props => [reason ?? ''];
}

class Reconnecting extends ConnectionState {
  final int attempt;

  const Reconnecting({this.attempt = 1});

  @override
  List<Object> get props => [attempt];
}
