import 'dart:convert';
import 'dart:typed_data';

import 'package:rxdart/subjects.dart';
import 'package:decimal/decimal.dart';
import 'package:convert/convert.dart';
import 'package:web3dart/web3dart.dart' as web3dart;

import '../cores/paper_wallet.dart';
import '../cores/account.dart';
import '../models/account.model.dart';
import '../models/transaction.model.dart';
import '../models/utxo.model.dart';
import '../services/account_service.dart';
import '../services/transaction_service.dart';
import '../services/transaction_service_based.dart';
import '../services/transaction_service_bitcoin.dart';
import '../services/transaction_service_ethereum.dart';
import '../constants/account_config.dart';
import '../helpers/cryptor.dart';
import '../helpers/utils.dart';
import '../helpers/converter.dart';
import '../helpers/rlp.dart' as rlp;
import '../database/db_operator.dart';
import '../database/entity/user.dart';
import '../database/entity/account_currency.dart';
import '../database/entity/transaction.dart';

import '../helpers/logger.dart';

class TransactionRepository {
  Currency _currency;
  AccountService _accountService;
  TransactionService _transactionService;
  PublishSubject<AccountMessage> get listener => AccountCore().messenger;
  String _address;

  TransactionRepository();

  void setCurrency(Currency currency) {
    this._currency = currency;
    _accountService = AccountCore().getService(this._currency.accountType);
    switch (this._currency.accountType) {
      case ACCOUNT.BTC:
        _transactionService =
            BitcoinTransactionService(TransactionServiceBased());
        break;
      case ACCOUNT.ETH:
        _transactionService =
            EthereumTransactionService(TransactionServiceBased());
        break;
      case ACCOUNT.XRP:
        // TODO: Handle this case.
        break;
    }
  }

  Currency get currency => this._currency;

  bool verifyAmount(Decimal amount, {Decimal fee}) {
    bool result =
        Decimal.parse(_currency.amount) - amount - fee >= Decimal.zero;
    Log.debug('verifyAmount: $result');
    // TODO TEST
    result = true;
    return result;
  }

  Future<List<Transaction>> getTransactions() async {
    List<TransactionEntity> transactions = await DBOperator()
        .transactionDao
        .findAllTransactionsById(this._currency.id);
    List<Transaction> txs = transactions
        .map((tx) => Transaction.fromTransactionEntity(tx))
        .toList();
    return txs;
  }

  Future<String> getReceivingAddress() async {
    // TEST: is BackendAddress correct?
    List result = await _accountService.getReceivingAddress(this._currency.id);
    String address = result[0];

    return address;
  }

  Future<List<dynamic>> getTransactionFee(
      {String address, Decimal amount, String message}) async {
    Map<TransactionPriority, Decimal> _fee =
        await _accountService.getTransactionFee(this._currency.blockchainId);

    // TODO if (message != null)
    Decimal _gasLimit;
    switch (this._currency.accountType) {
      case ACCOUNT.BTC:
        List<UnspentTxOut> unspentTxOuts =
            await _accountService.getUnspentTxOut(_currency.id);
        Map<TransactionPriority, Decimal> fee = {
          TransactionPriority.slow:
              _transactionService.calculateTransactionVSize(
            unspentTxOuts: unspentTxOuts,
            amount: amount,
            feePerByte: _fee[TransactionPriority.slow],
            message: rlp.toBuffer(message ?? Uint8List(0)),
          ),
          TransactionPriority.standard:
              _transactionService.calculateTransactionVSize(
            unspentTxOuts: unspentTxOuts,
            amount: amount,
            feePerByte: _fee[TransactionPriority.standard],
            message: rlp.toBuffer(message ?? Uint8List(0)),
          ),
          TransactionPriority.fast:
              _transactionService.calculateTransactionVSize(
            unspentTxOuts: unspentTxOuts,
            amount: amount,
            feePerByte: _fee[TransactionPriority.fast],
            message: rlp.toBuffer(message ?? Uint8List(0)),
          ),
        };
        return [fee];
        break;
      case ACCOUNT.ETH:
        if (this._address == null) {
          _address =
              (await _accountService.getChangingAddress(_currency.id))[0];
        }
        String to = address.contains(':') ? address.split(':')[1] : address;
        String from =
            _address.contains(':') ? _address.split(':')[1] : _address;
        if (currency.symbol.toLowerCase() != 'eth') {
          // ERC20
          Log.debug('ETH this._currency.decimals: ${this._currency.decimals}');
          List<int> erc20Func = Cryptor.keccak256round(
              utf8.encode('transfer(address,uint256)'),
              round: 1);
          message = '0x' +
              hex.encode(erc20Func.take(4).toList() +
                  hex.decode(to.substring(2).padLeft(64, '0')) +
                  hex.decode(hex
                      .encode(encodeBigInt(BigInt.parse(
                          Converter.toCurrencySmallestUnit(
                                  amount, _currency.decimals)
                              .toString())))
                      .padLeft(64, '0')) +
                  rlp.toBuffer(message ?? Uint8List(0)));
          Log.debug('ETH erc20Func: $erc20Func');

          amount = Decimal.zero;
          to = this._currency.contract;
        }
        _gasLimit = await _accountService.estimateGasLimit(
            this._currency.blockchainId,
            from,
            to,
            amount.toString(),
            '0x' +
                hex.encode(
                    message == null ? Uint8List(0) : rlp.toBuffer(message)));
        return [_fee, _gasLimit];
        break;
      case ACCOUNT.XRP:
        // TODO: Handle this case.
        return [_fee];
        break;
      default:
        return [_fee, _gasLimit];
    }
  }

  Future<bool> verifyAddress(String address, bool publish) async {
    bool verified = false;
    if (this._address == null) {
      _address = (await _accountService.getChangingAddress(_currency.id))[0];
    }
    verified = address != _address && address.length > 0;
    if (verified) {
      verified = _transactionService.verifyAddress(address, publish);
    }
    return verified;
  }

  Future<Uint8List> _getSeed(String pwd) async {
    // TODO TEST
    // return Uint8List.fromList(hex.decode(
    //     'd130e96ae9f5ede60e33c5264d1e2beb03c54b5eb67d8d52773a408287178ccc'));
    // TEST (END)
    UserEntity user = await DBOperator().userDao.findUser();
    web3dart.Wallet wallet = PaperWallet.jsonToWallet([user.keystore, pwd]);
    List<int> seed = PaperWallet.magicSeed(wallet.privateKey.privateKey);
    return Uint8List.fromList(seed);
  }

  Future<Uint8List> getPubKey(String pwd, int changeIndex, int keyIndex) async {
    Uint8List seed = await _getSeed(pwd);
    return await PaperWallet.getPubKey(seed, changeIndex, keyIndex);
  }

  Future<Uint8List> getPrivKey(
      String pwd, int changeIndex, int keyIndex) async {
    Uint8List seed = await _getSeed(pwd);
    Uint8List result =
        await PaperWallet.getPrivKey(seed, changeIndex, keyIndex);
    // result = await PaperWallet.getPrivKey(
    //     Uint8List.fromList(hex.decode(
    //         'd36777597b9c5cc58a64a4fb842a206bd86da50f276b783aae0cf87e5b058821')),
    //     changeIndex,
    //     keyIndex);
    Log.warning("getPrivKey seed: ${hex.encode(seed)}");
    return result;
  }

  Future<List> prepareTransaction(String pwd, String to, Decimal amount,
      {Decimal fee, Decimal gasPrice, Decimal gasLimit, String message}) async {
    switch (this._currency.accountType) {
      case ACCOUNT.BTC:
        String changeAddress;
        int changeIndex;
        List<UnspentTxOut> unspentTxOuts =
            await _accountService.getUnspentTxOut(_currency.id);
        Decimal utxoAmount = Decimal.zero;
        Log.btc('amount + fee: ${amount + fee}');
        for (UnspentTxOut utxo in unspentTxOuts) {
          Log.btc('utxo.locked: ${utxo.locked}');

          if (utxo.locked || !(utxo.amount > Decimal.zero) || utxo.type == null)
            continue;
          utxoAmount += utxo.amount; // in currency uint
          Log.btc('utxoAmount: $utxoAmount');
          Log.btc('utxo.amount: ${utxo.amount}');
          utxo.privatekey =
              await getPrivKey(pwd, utxo.chainIndex, utxo.keyIndex);
          utxo.publickey = await getPubKey(pwd, utxo.chainIndex, utxo.keyIndex);
          if (utxoAmount > (amount + fee)) {
            List result =
                await _accountService.getChangingAddress(_currency.id);
            Log.btc('prepareTransaction getChangingAddress: $result');
            changeAddress = result[0];
            changeIndex = result[1];
            break;
          } else if (utxoAmount == (amount + fee)) break;
        }
        Transaction transaction = _transactionService.prepareTransaction(
            this._currency.publish,
            to,
            Converter.toCurrencySmallestUnit(amount, this._currency.decimals),
            message == null ? Uint8List(0) : rlp.toBuffer(message),
            accountcurrencyId: this._currency.id,
            fee: Converter.toCurrencySmallestUnit(fee, this._currency.decimals),
            unspentTxOuts: unspentTxOuts,
            changeIndex: changeIndex,
            changeAddress: changeAddress);
        Decimal balance = Decimal.parse(this._currency.amount) - amount - fee;
        return [
          transaction,
          balance.toString()
        ]; // [Transaction, String(balance)]
        break;
      case ACCOUNT.ETH:
        int nonce = await _accountService.getNonce(
            this._currency.blockchainId, this._address);

        Log.debug('ETH gasLimit: $gasLimit');
        Decimal balance =
            Decimal.parse(this._currency.amount) - amount - gasPrice * gasLimit;
        if (currency.symbol.toLowerCase() != 'eth') {
          // ERC20
          balance = amount;
          amount = Decimal.zero;
          to = this._currency.contract;
        }

        Transaction transaction = _transactionService.prepareTransaction(
            this._currency.publish,
            to,
            Converter.toCurrencySmallestUnit(amount, this._currency.decimals),
            message == null ? Uint8List(0) : rlp.toBuffer(message),
            nonce: nonce,
            gasPrice: Converter.toCurrencySmallestUnit(
                gasPrice, _transactionService.currencyDecimals),
            gasLimit: gasLimit,
            chainId: _currency.chainId,
            privKey: await getPrivKey(pwd, 0, 0),
            changeAddress: this._address);

        Log.debug(
            'transaction: ${hex.encode(transaction.serializeTransaction)}');

        return [transaction, balance.toString()];
        break;
      case ACCOUNT.XRP:
        return null;
        // TODO: Handle this case.
        break;
      default:
        return null;
    }
  }

  Future<bool> publishTransaction(
      Transaction transaction, String balance) async {
    Log.debug('PublishTransaction fee: ${transaction.fee}');
    Log.debug('PublishTransaction amount: ${transaction.amount}');
    Log.debug(
        'PublishTransaction this._currency.blockchainId: ${this._currency.blockchainId}');
    Log.debug('PublishTransaction balance: $balance');
    List result = await _accountService.publishTransaction(
        this._currency.blockchainId, transaction);
    Log.debug('PublishTransaction result: $result');
    bool success = result[0];
    Transaction _transaction = result[1];
    Log.debug('PublishTransaction _transaction: $_transaction');

    if (!success) return success;
    Log.debug('PublishTransaction result: ${result[0]}');
    _pushResult(_transaction, Decimal.parse(balance));

    return result[0];
  }

  _pushResult(Transaction transaction, Decimal balance) async {
    // TODO updateCurrencyAmount
    Decimal _amount;
    Decimal _fee;
    Decimal _gasPrice;
    Currency _curr = this._currency;
    Log.debug('newCurr _curr.amount: ${_curr.amount}');
    _curr.amount = balance.toString();
    switch (this._currency.accountType) {
      case ACCOUNT.BTC:
        _amount = Converter.toCurrencyUnit(
            transaction.amount, this._currency.decimals);
        _fee =
            Converter.toCurrencyUnit(transaction.fee, this._currency.decimals);
        _updateAccountCurrencyEntity(this._currency.id, balance.toString());
        break;
      case ACCOUNT.ETH:
        Log.warning('newCurr this._currency.symbol: ${this._currency.symbol}');
        Log.debug(
            'newCurr this._currency.accountId: ${this._currency.accountId}');
        Log.debug(
            'newCurr this._currency.currencyId: ${this._currency.currencyId}');
        Log.debug('newCurr this._currency.id: ${this._currency.id}');
        Log.debug(
            'newCurr this._currency.decimals: ${this._currency.decimals}');
        if (this._currency.symbol.toLowerCase() == 'eth') {
          _amount = Converter.toCurrencyUnit(
              transaction.amount, this._currency.decimals);
          _fee = Converter.toEthCoinUnit(transaction.fee);
          _gasPrice = Converter.toEthCoinUnit(transaction.gasPrice);
          _updateAccountCurrencyEntity(this._currency.id, balance.toString());
        } else {
          _curr.amount =
              (Decimal.parse(this._currency.amount) - balance).toString();
          _amount = Converter.toCurrencyUnit(balance, this._currency.decimals);
          _fee = Converter.toEthCoinUnit(transaction.fee);
          _gasPrice = Converter.toEthCoinUnit(transaction.gasPrice);
          _updateAccountCurrencyEntity(this._currency.id, balance.toString());
          _updateAccountCurrencyEntity(this._currency.accountId,
              (transaction.gasPrice * transaction.gasUsed).toString());
        }
        break;
      case ACCOUNT.XRP:
        // TODO: Handle this case.
        break;
    }

    Log.debug('newCurr _curr.amount: ${_curr.amount}');
    Log.debug('newCurr balance: $balance');
    AccountMessage currMsg =
        AccountMessage(evt: ACCOUNT_EVT.OnUpdateCurrency, value: [_curr]);
    listener.add(currMsg);

    // insertTransaction
    TransactionEntity tx = TransactionEntity(
      transactionId: transaction.id,
      accountcurrencyId: this._currency.id,
      txId: transaction.txId,
      amount: _amount.toString(),
      fee: _fee.toString(),
      gasPrice: _gasPrice.toString(),
      gasUsed: transaction?.gasUsed?.toInt(),
      direction:
          transaction?.direction?.title ?? TransactionDirection.sent.title,
      sourceAddress: transaction.sourceAddresses,
      destinctionAddress: transaction.destinationAddresses,
      confirmation: transaction?.confirmations ?? 0,
      timestamp: transaction?.timestamp ??
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
      note: hex.encode(transaction?.message ?? Uint8List(0)),
      status: transaction?.status?.title ?? TransactionStatus.pending.title,
    );
    Log.debug('PublishTransaction tx note: ${tx.note}');
    await DBOperator().transactionDao.insertTransaction(tx);

    // inform screen
    List transactions = await DBOperator()
        .transactionDao
        .findAllTransactionsById(this._currency.id);
    transactions.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    AccountMessage txMsg =
        AccountMessage(evt: ACCOUNT_EVT.OnUpdateTransactions, value: {
      "currency": this._currency,
      "transactions": transactions
          .map((tx) => Transaction.fromTransactionEntity(tx))
          .toList()
    });
    Log.debug('transactions: $transactions');

    listener.add(txMsg);
  }

  _updateAccountCurrencyEntity(String id, String balance) async {
    AccountCurrencyEntity account =
        await DBOperator().accountCurrencyDao.findOneByAccountyId(id);
    Log.debug(
        'newCurr account accountcurrencyId: ${account.accountcurrencyId}');
    Log.debug('newCurr account currencyId: ${account.currencyId}');
    Log.debug('newCurr account accountId: ${account.accountId}');
    Log.debug('newCurr account balance: ${account.balance}');

    AccountCurrencyEntity updateAccount = AccountCurrencyEntity(
        accountcurrencyId: account.accountId,
        accountId: account.accountId,
        numberOfUsedExternalKey: account.numberOfUsedExternalKey,
        numberOfUsedInternalKey: account.numberOfUsedInternalKey,
        currencyId: account.currencyId,
        lastSyncTime: account.lastSyncTime,
        balance: balance);
    await DBOperator().accountCurrencyDao.insertAccount(updateAccount);
    Log.debug('PublishTransaction updateAccount: $updateAccount');
  }
}
