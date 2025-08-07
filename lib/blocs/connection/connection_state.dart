import 'package:equatable/equatable.dart';

abstract class ConnectionState extends Equatable {
  const ConnectionState();

  @override
  List<Object> get props => [];
}

class ConnectionInitial extends ConnectionState {}

class Connected extends ConnectionState {
  const Connected();
}

class Disconnected extends ConnectionState {
  final String? reason;
  final bool isIntentional;

  const Disconnected({this.reason, this.isIntentional = false});

  @override
  List<Object> get props => [reason ?? '', isIntentional];
}

class Reconnecting extends ConnectionState {
  final int attempt;

  const Reconnecting({this.attempt = 1});

  @override
  List<Object> get props => [attempt];
}
