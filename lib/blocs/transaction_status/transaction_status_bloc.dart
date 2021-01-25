import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../models/account.model.dart';
import '../../models/transaction.model.dart';
import '../../repositories/transaction_repository.dart';
import '../../repositories/account_repository.dart';

part 'transaction_status_event.dart';
part 'transaction_status_state.dart';

class TransactionStatusBloc
    extends Bloc<TransactionStatusEvent, TransactionStatusState> {
  TransactionRepository _repo;
  AccountRepository _accountRepo;
  StreamSubscription _subscription;

  TransactionStatusBloc(this._repo, this._accountRepo)
      : super(TransactionStatusInitial(null, [])) {
    this._repo.listener.listen((msg) {
      if (msg.evt == ACCOUNT_EVT.OnUpdateAccount) {
        print("msg.value ${(msg.value as Currency).name}");
        this.add(UpdateCurrency(msg.value));
      }
      if (msg.evt == ACCOUNT_EVT.OnUpdateTransactions) {
        this.add(UpdateTransactionList(
            msg.value['currency'], msg.value['transactions']));
      }
    });
  }

  @override
  Stream<TransactionStatusState> mapEventToState(
    TransactionStatusEvent event,
  ) async* {
    if (event is UpdateCurrency) {
      if (state.currency == null ||
          state.currency.symbol == event.currency.symbol) {
        final List<Transaction> transactions =
            _repo.getTransactionsFromDB(event.currency); // getTransactionFromDB
        yield TransactionStatusLoaded(event.currency, transactions);
      }
    }
    if (event is UpdateTransactionList) {
      if (state.currency != null &&
          state.currency.symbol == event.currency.symbol) {
        yield TransactionStatusLoaded(event.currency, event.transactions);
      }
    }
  }
}
