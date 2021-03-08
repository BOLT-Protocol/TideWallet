part of 'walletconnect_bloc.dart';

abstract class WalletConnectEvent extends Equatable {
  const WalletConnectEvent();

  @override
  List<Object> get props => [];
}

class ScanWC extends WalletConnectEvent {
  final String uri;

  ScanWC(this.uri);
}

class ApproveWC extends WalletConnectEvent {}

class DisconnectWC extends WalletConnectEvent {
  final String message;

  DisconnectWC(this.message);
}