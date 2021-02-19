part of 'transaction_bloc.dart';

enum TransactionFormError {
  addressInvalid,
  amountInsufficient,
}

abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object> get props => [];
}

class TransactionInitial extends TransactionState {
  final String address;
  final Decimal amount;
  final Decimal spandable;
  final TransactionPriority priority;
  final Decimal gasLimit;
  final Decimal gasPrice;
  final Decimal fee;
  final String feeToFiat;
  final String estimatedTime;
  final List<bool> rules;
  final TransactionFormError error;

  static const defaultValid = [false, false];

  TransactionInitial(
      {this.address,
      this.amount,
      this.spandable,
      this.priority = TransactionPriority.standard,
      this.gasLimit,
      this.gasPrice,
      this.fee,
      this.feeToFiat = "",
      this.estimatedTime = "10~30",
      this.rules = defaultValid,
      this.error});

  TransactionState copyWith({
    String address,
    Decimal amount,
    Decimal spandable,
    TransactionPriority priority,
    Decimal gasLimit,
    Decimal gasPrice,
    Decimal fee,
    String feeToFiat,
    String estimatedTime,
    List<bool> rules,
    TransactionFormError error,
  }) {
    return TransactionInitial(
      address: address ?? this.address,
      amount: amount ?? this.amount,
      spandable: spandable ?? this.spandable,
      priority: priority ?? this.priority,
      gasLimit: gasLimit ?? this.gasLimit,
      gasPrice: gasPrice ?? this.gasPrice,
      fee: fee ?? this.fee,
      feeToFiat: feeToFiat ?? this.feeToFiat,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      rules: rules ?? this.rules,
      error: error,
    );
  }

  @override
  List<Object> get props => [
        address,
        amount,
        spandable,
        priority,
        gasLimit,
        gasPrice,
        fee,
        feeToFiat,
        estimatedTime,
        rules,
        error
      ];
}

class CreateTransactionFail extends TransactionState {}

class TransactionSent extends TransactionState {}

class TransactionPublishing extends TransactionState {}
