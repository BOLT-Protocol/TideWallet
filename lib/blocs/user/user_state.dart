part of 'user_bloc.dart';

abstract class UserState extends Equatable {
  const UserState();

  @override
  List<Object> get props => [];
}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserSuccess extends UserState {}

class UserFail extends UserState {}

class VerifyingPassword extends UserState {}

class PasswordVerified extends UserState {}

class PasswordInvalid extends UserState {}

class PasswordUpdated extends UserState {}
