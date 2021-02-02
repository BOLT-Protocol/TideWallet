import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme.dart';
import '../models/account.model.dart';
import '../widgets/appBar.dart';
import '../widgets/dialogs/dialog_controller.dart';
import '../widgets/dialogs/loading_dialog.dart';
import '../widgets/buttons/secondary_button.dart';
import '../helpers/i18n.dart';
import '../repositories/account_repository.dart';
import '../blocs/receive/receive_bloc.dart';
import '../constants/account_config.dart';

class ReceiveScreen extends StatefulWidget {
  static const routeName = '/receive';
  @override
  _ReceiveScreenState createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final t = I18n.t;
  AccountRepository _repo;
  ReceiveBloc _bloc;
  Currency _currency;
  String _address = '';
  bool _isCalled = false;

  @override
  void didChangeDependencies() {
    Map<String, Currency> arg = ModalRoute.of(context).settings.arguments;
    _currency = arg["currency"];
    _repo = Provider.of<AccountRepository>(context);
    print("_address: $_address");
    if (!_isCalled) {
      _bloc = ReceiveBloc(_repo)..add(GetReceivingAddress(_currency));
      _isCalled = true;
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: GeneralAppbar(
        title: t('my_wallet'),
        routeName: ReceiveScreen.routeName,
      ),
      body: BlocListener<ReceiveBloc, ReceiveState>(
          cubit: _bloc,
          listener: (context, state) {
            print('state: $state');
            if (state is AddressLoading) {
              DialogController.showUnDissmissible(context, LoadingDialog());
            }
            if (state is AddressLoaded) {
              DialogController.dismiss(context);
              setState(() {
                _address = state.address;
                print('_address: $_address');
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 0, horizontal: 16.0),
            margin: EdgeInsets.symmetric(vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  child: Text(
                    '${t('remit')} ${_currency.symbol.toUpperCase()}',
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  height: 40,
                  child: Text(
                    _currency.accountType != ACCOUNT.BTC
                        ? t('btc_receving_address_hint')
                        : '',
                    style: Theme.of(context).textTheme.subtitle2,
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  child: QrImage(
                    data: _address,
                    version: QrVersions.auto,
                    size: width * 0.7,
                  ),
                ),
                Spacer(),
                Container(
                  height: 60,
                  margin: EdgeInsets.symmetric(
                      horizontal: width * 0.035, vertical: 20),
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  color: MyColors.secondary_11,
                  child: Center(child: Text(_address)),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: width * 0.1),
                  child: SecondaryButton(
                    t('copy_wallet_address'),
                    () {
                      Clipboard.setData(ClipboardData(text: _address));
                    },
                    textColor: Theme.of(context).accentColor,
                    borderColor: Theme.of(context).accentColor,
                  ),
                )
              ],
            ),
          )),
    );
  }
}
