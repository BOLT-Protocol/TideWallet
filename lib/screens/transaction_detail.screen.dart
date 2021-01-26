import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../blocs/transaction_status/transaction_status_bloc.dart';

import '../theme.dart';
import '../helpers/i18n.dart';
import '../helpers/formatter.dart';
import '../models/account.model.dart';
import '../models/transaction.model.dart';
import '../widgets/appBar.dart';
import '../widgets/dash_line_divider.dart';
import '../repositories/account_repository.dart';
import '../repositories/transaction_repository.dart';

class TransactionDetailScreen extends StatefulWidget {
  // final Currency currency;
  // final Transaction transaction;

  static const routeName = '/transaction-detail';

  const TransactionDetailScreen({Key key}) : super(key: key);

  @override
  _TransactionDetailScreenState createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final t = I18n.t;
  TransactionStatusBloc _bloc;
  TransactionRepository _repo;
  AccountRepository _accountRepo;
  Currency _currency;
  Transaction _transaction;

  @override
  void didChangeDependencies() {
    Map<String, dynamic> arg = ModalRoute.of(context).settings.arguments;
    _currency = arg["currency"];
    _transaction = arg["transaction"];
    _repo = Provider.of<TransactionRepository>(context);
    _accountRepo = Provider.of<AccountRepository>(context);
    print(_transaction.status);
    print(_transaction.amount);
    print(_transaction.confirmations);
    print(_transaction.direction);
    _bloc = TransactionStatusBloc(_repo, _accountRepo)
      ..add(UpdateTransaction(_transaction)); // TODO GetTransactionList
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print("build");
    return Scaffold(
      appBar: GeneralAppbar(
        title: t('transaction_detail'),
        routeName: TransactionDetailScreen.routeName,
      ),
      body: BlocBuilder<TransactionStatusBloc, TransactionStatusState>(
          cubit: _bloc,
          builder: (context, state) {
            _transaction = state.transaction ?? _transaction;
            return Container(
              padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              margin: EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_transaction.direction == TransactionDirection.sent ? "-" : "+"} ${_transaction.amount}',
                        style: Theme.of(context).textTheme.headline1.copyWith(
                            color:
                                _transaction.status != TransactionStatus.success
                                    ? MyColors.secondary_03
                                    : _transaction.direction.color,
                            fontSize: 32),
                      ),
                      SizedBox(
                        width: 8,
                      ),
                      Text(
                        'btc',
                        style: Theme.of(context).textTheme.headline1.copyWith(
                              color: _transaction.status !=
                                      TransactionStatus.success
                                  ? MyColors.secondary_03
                                  : _transaction.direction.color,
                            ),
                      )
                    ],
                  ),
                  SizedBox(height: 24),
                  DashLineDivider(
                    color: Theme.of(context).dividerColor,
                  ),
                  SizedBox(height: 16),
                  Align(
                    child: Text(
                      t('status'),
                      style: Theme.of(context).textTheme.caption,
                    ),
                    alignment: Alignment.centerLeft,
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Align(
                      child: Row(
                        children: [
                          Text(
                            '${t(_transaction.status.title)} (${_transaction.confirmations} ${t('confirmation')})',
                            style: Theme.of(context)
                                .textTheme
                                .bodyText1
                                .copyWith(color: _transaction.status.color),
                          ),
                          SizedBox(width: 8),
                          ImageIcon(
                            AssetImage(_transaction.status.iconPath),
                            size: 20.0,
                            color: _transaction.status.color,
                          ),
                        ],
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  SizedBox(height: 24),
                  Align(
                    child: Text(
                      t('time'),
                      style: Theme.of(context).textTheme.caption,
                    ),
                    alignment: Alignment.centerLeft,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Align(
                      child: Text(
                        '(${Formatter.dateTime(_transaction.timestamp)})',
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  SizedBox(height: 24),
                  Align(
                    child: Text(
                      t('transfer_to'),
                      style: Theme.of(context).textTheme.caption,
                    ),
                    alignment: Alignment.centerLeft,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Align(
                      child: Text(
                        _transaction.address,
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  SizedBox(height: 24),
                  Align(
                    child: Text(
                      t('transaction_fee'),
                      style: Theme.of(context).textTheme.caption,
                    ),
                    alignment: Alignment.centerLeft,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Align(
                      child: Text(
                        '${Formatter.formaDecimal(_transaction.fee)} btc',
                        style: Theme.of(context).textTheme.bodyText1,
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                  SizedBox(height: 24),
                  Align(
                    child: Text(
                      t('transaction_id'),
                      style: Theme.of(context).textTheme.caption,
                    ),
                    alignment: Alignment.centerLeft,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Container(
                          // child: Image.asset('assets/images/ic_btc_web.png'),
                          child: Image.asset(_currency.imgPath),
                          width: 24,
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        GestureDetector(
                          onTap: _launchURL,
                          child: Text(
                            Formatter.formateAdddress(_transaction.txId),
                            style: Theme.of(context)
                                .textTheme
                                .bodyText1
                                .copyWith(
                                    color: Theme.of(context).primaryColor,
                                    decoration: TextDecoration.underline),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
    );
  }
}

_launchURL() async {
  const url = 'https://flutter.dev';
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    throw 'Could not launch $url';
  }
}