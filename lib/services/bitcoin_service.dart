import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:convert/convert.dart';

import 'account_service.dart';
import 'account_service_decorator.dart';
import '../models/api_response.mode.dart';
import '../models/transaction.model.dart';
import '../models/bitcoin_transaction.model.dart';
import '../models/utxo.model.dart';
import '../helpers/logger.dart';
import '../helpers/http_agent.dart';
import '../constants/endpoint.dart';
import '../constants/account_config.dart';
import '../database/db_operator.dart';
import '../database/entity/utxo.dart';

import 'dart:typed_data'; //TODO TEST
import '../cores/paper_wallet.dart'; //TODO TEST
import '../helpers/bitcoin_based_utils.dart'; //TODO TEST

class BitcoinService extends AccountServiceDecorator {
  Timer _utxoTimer;
  BitcoinService(AccountService service) : super(service) {
    this.base = ACCOUNT.BTC;
    this.syncInterval = 1 * 60 * 1000;
    // this.path = "m/44'/0'/0'";
  }
  Timer _timer;
  int _numberOfUsedExternalKey;
  int _numberOfUsedInternalKey;
  int _lastSyncTimestamp;

  @override
  getTransactions() {
    // TODO: implement getTransactions
    throw UnimplementedError();
  }

  @override
  void init(String id, ACCOUNT base, {int interval}) {
    this.service.init(id, this.base, interval: this.syncInterval);
  }

  @override
  prepareTransaction() {
    // TODO: implement prepareTransaction
    throw UnimplementedError();
  }

  @override
  Future start() async {
    await this.service.start();

    await this._syncUTXO();

    this._utxoTimer =
        Timer.periodic(Duration(milliseconds: this.syncInterval), (_) {
      this._syncUTXO();
    });
  }

  @override
  void stop() {
    this.service.stop();

    _utxoTimer?.cancel();
  }

  @override
  Future<int> getNonce(String blockchainId, String address) {
    // TODO: implement getNonce
    throw UnimplementedError();
  }

  @override
  Future<Decimal> estimateGasLimit(
      String blockchainId, String from, String to, String amount, String data) {
    // TODO: implement estimateGasLimit
    throw UnimplementedError();
  }

  @override
  Future<Map<TransactionPriority, Decimal>> getTransactionFee(
      String blockchainId) async {
    // TODO getSyncFeeAutomatically
    APIResponse response = await HTTPAgent()
        .get('${Endpoint.SUSANOO}/blockchain/$blockchainId/fee');
    Map<String, dynamic> data = response.data; // FEE will return String

    Map<TransactionPriority, Decimal> transactionFee = {
      TransactionPriority.slow: Decimal.parse(data['slow']),
      TransactionPriority.standard: Decimal.parse(data['standard']),
      TransactionPriority.fast: Decimal.parse(data['fast']),
    };
    return transactionFee;
  }

  @override
  Future<List> getChangingAddress(String currencyId) async {
    APIResponse response = await HTTPAgent()
        .get('${Endpoint.SUSANOO}/wallet/account/address/$currencyId/change');
    Map data = response.data;
    String _address = data['address'];
    _numberOfUsedInternalKey = data['change_index'];
    return [_address, _numberOfUsedInternalKey];
  }

  @override
  Future<List> getReceivingAddress(String currencyId) async {
    APIResponse response = await HTTPAgent()
        .get('${Endpoint.SUSANOO}/wallet/account/address/$currencyId/receive');
    Map data = response.data;
    String address = data['address'];
    _numberOfUsedExternalKey = data['key_index'];

    Log.debug('api address: $address');
    Log.debug('api keyIndex: $_numberOfUsedExternalKey');
    String seed =
        '74a0b10d85dea97d53ff42a89f34a8447bbd041dcb573333358a03d5d1cfff0e';
    // '59f45d6afb9bc00380fed2fcfdd5b36819acab89054980ad6e5ff90ba19c5347'; // 上一個有eth的 seed
    Uint8List publicKey = await PaperWallet.getPubKey(
        hex.decode(seed), 0, _numberOfUsedExternalKey);
    String calAddress = pubKeyToP2wpkhAddress(publicKey, 'tb');
    Log.debug('calculated address: $calAddress');
    return [address, _numberOfUsedExternalKey];
  }

  @override
  Future<List<UnspentTxOut>> getUnspentTxOut(String currencyId) async {
    List<UtxoEntity> utxos =
        await DBOperator().utxoDao.findAllUtxosByCurrencyId(currencyId);
    return utxos.map((utxo) => UnspentTxOut.fromUtxoEntity(utxo)).toList();
  }

  @override
  Future<bool> publishTransaction(
      String blockchainId, Transaction transaction) async {
    APIResponse response = await HTTPAgent().post(
        '${Endpoint.SUSANOO}/blockchain/$blockchainId/push-tx',
        {"hex": hex.encode(transaction.serializeTransaction)});
    bool success = response.success;

    if (success) {
      // updateUsedUtxo
      BitcoinTransaction _transaction = transaction;
      _transaction.inputs.forEach((Input input) async {
        UnspentTxOut _utxo = input.utxo;
        _utxo.locked = true;
        await DBOperator()
            .utxoDao
            .updateUtxo(UtxoEntity.fromUnspentUtxo(_utxo));
      });
      // insertChangeUtxo
      if (transaction.changeUtxo != null) {
        await DBOperator()
            .utxoDao
            .insertUtxo(UtxoEntity.fromUnspentUtxo(transaction.changeUtxo));
      }
      // TODO informBackend
// await HTTPAgent().post(
//         '${Endpoint.SUSANOO}/blockchain/$blockchainId/change-utxo',
//         {"changeUtxo": transaction.changeUtxo});
    }

    return success;
  }

  Future _syncUTXO() async {
    int now = DateTime.now().millisecondsSinceEpoch;

    if (now - this.service.lastSyncTimestamp > this.syncInterval) {
      Log.btc('_syncUTXO');
      String currencyId = this.service.accountId;

      // APIResponse response = await HTTPAgent()
      //     .get('${Endpoint.SUSANOO}/wallet/account/txs/uxto/$currencyId');
      // List<dynamic> datas = response.data;
      // List<UtxoEntity> utxos = datas
      //     .map((data) => UtxoEntity(
      //           data['id'],
      //           currencyId,
      //           data['txid'],
      //           data['vout'],
      //           data['type'],
      //           data['amount'],
      //           data['chain_index'],
      //           data['key_index'],
      //           data['script'],
      //           data['timestamp'],
      //           false,
      //           BitcoinTransaction.DEFAULT_SEQUENCE,
      //         ))
      //     .toList();
      // DBOperator().utxoDao.insertUtxos(utxos);
    }
  }
}
