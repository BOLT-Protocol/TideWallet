part of 'account_bloc.dart';

@immutable
abstract class AccountEvent extends Equatable {}

class UpdateAccount extends AccountEvent {
  final Currency account;

  UpdateAccount(this.account);

  @override
  List<Object> get props => [];

}

class CleanAccount extends AccountEvent {
  @override
  List<Object> get props => [];
}