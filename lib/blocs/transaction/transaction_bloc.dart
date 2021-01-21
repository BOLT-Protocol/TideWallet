import 'dart:async';
import 'dart:math' as math;

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:decimal/decimal.dart';

import '../../repositories/account_repository.dart';
import '../../repositories/transaction_repository.dart';
import '../../models/transaction.model.dart';

part 'transaction_event.dart';
part 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  TransactionRepository _repo;
  AccountRepository _accountRepo;
  Map<TransactionPriority, String> _gasPrice;
  String _gasLimit;

  TransactionBloc(this._repo, this._accountRepo) : super(TransactionInitial());

  @override
  Stream<TransactionState> mapEventToState(
    TransactionEvent event,
  ) async* {
    print("event: $event");
    TransactionInitial _state = state;
    if (event is FetchTransactionFee) {
      _gasPrice = await _accountRepo.fetchGasPrice();
      _gasLimit = await _accountRepo.fetchGasLimit();
      Decimal fee = Decimal.parse(_gasPrice[_state.priority]) *
          Decimal.parse(_gasLimit) /
          Decimal.fromInt(BigInt.from(10).pow(9).toInt());
      Decimal feeToFiat = fee * Decimal.fromInt(68273);
      // TODO toEther()
      yield _state.copyWith(
        fee: '$fee',
        feeToFiat: '$feeToFiat',
        gasLimit: _gasLimit,
        gasPrice: _gasPrice[_state.priority],
      );
    }
    if (event is ValidAddress) {
      print("ValidAddress address: ${event.address}");
      List<bool> _rules = [
        _accountRepo.validAddress(event.address),
        _state.rules[1]
      ];
      print(_rules);
      yield _state.copyWith(
        address: event.address,
        rules: _rules,
      );
    }
    if (event is ValidAmount) {
      List<bool> _rules = [
        _state.rules[0],
        _accountRepo.validAmount(event.amount,
            priority: TransactionPriority.standard)
      ];
      print(_rules);
      yield _state.copyWith(
        amount: event.amount,
        rules: _rules,
      );
    }
    if (event is ChangePriority) {
      // TODO getTransactionFee
      List<bool> _rules = [
        _state.rules[0],
        _accountRepo.validAmount(_state.amount, priority: event.priority)
      ];
      Decimal fee = Decimal.parse(_gasPrice[event.priority]) *
          Decimal.parse(_gasLimit) /
          Decimal.fromInt(BigInt.from(10).pow(9).toInt());
      Decimal feeToFiat = fee * Decimal.fromInt(68273);
      yield _state.copyWith(
        priority: event.priority,
        fee: '$fee',
        feeToFiat: '$feeToFiat',
        gasLimit: _gasLimit,
        gasPrice: _gasPrice[event.priority],
        rules: _rules,
      );
    }
    if (event is InputGasLimit) {
      if (_state.gasPrice.isEmpty)
        yield _state.copyWith(gasLimit: event.gasLimit);
      List<bool> _rules = [
        _state.rules[0],
        _accountRepo.validAmount(_state.amount,
            gasLimit: event.gasLimit, gasPrice: _state.gasPrice)
      ];
      yield _state.copyWith(
        gasLimit: event.gasLimit,
        rules: _rules,
      );
    }
    if (event is InputGasPrice) {
      if (_state.gasLimit.isEmpty)
        yield _state.copyWith(gasLimit: event.gasPrice);
      List<bool> _rules = [
        _state.rules[0],
        _accountRepo.validAmount(_state.amount,
            gasLimit: _state.gasLimit, gasPrice: event.gasPrice)
      ];
      yield _state.copyWith(
        gasLimit: event.gasPrice,
        rules: _rules,
      );
    }
    if (event is ConfirmTransaction) {}
    if (event is CreateTransaction) {}
  }
}
