import 'package:equatable/equatable.dart';

abstract class ConnectionEvent extends Equatable {
  const ConnectionEvent();

  @override
  List<Object> get props => [];
}

class CheckConnection extends ConnectionEvent {}

class ConnectionEstablished extends ConnectionEvent {}

class ConnectionLost extends ConnectionEvent {
  final String? reason;

  const ConnectionLost({this.reason});

  @override
  List<Object> get props => [reason ?? ''];
}

class StartReconnection extends ConnectionEvent {
  final int attempt;

  const StartReconnection({this.attempt = 1});

  @override
  List<Object> get props => [attempt];
}

class ResetConnection extends ConnectionEvent {}

class IntentionalDisconnect extends ConnectionEvent {
  final String? reason;

  const IntentionalDisconnect({this.reason});

  @override
  List<Object> get props => [reason ?? ''];
}

class NetworkSignalLost extends ConnectionEvent {
  final String? reason;

  const NetworkSignalLost({this.reason});

  @override
  List<Object> get props => [reason ?? ''];
}

class NetworkRestored extends ConnectionEvent {
  final String? networkType;

  const NetworkRestored({this.networkType});

  @override
  List<Object> get props => [networkType ?? ''];
}

