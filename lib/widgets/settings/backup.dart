import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../blocs/backup/backup_bloc.dart';
import '../../widgets/buttons/secondary_button.dart';
import '../../widgets/dialogs/dialog_controller.dart';
import '../../widgets/dialogs/error_dialog.dart';
import '../../helpers/logger.dart';
import '../../helpers/i18n.dart';
import '../../theme.dart';

class BackupSetting extends StatefulWidget {
  final Widget item;

  BackupSetting(this.item);
  @override
  _BackupSettingState createState() => _BackupSettingState();
}

class _BackupSettingState extends State<BackupSetting> {
  BackupBloc _backupBloc;
  final GlobalKey globalKey = GlobalKey();
  final t = I18n.t;
  bool _clickedBackup = false;

  @override
  void didChangeDependencies() {
    _backupBloc = BlocProvider.of<BackupBloc>(context);
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BackupBloc, BackupState>(
      listener: (context, state) {
        if (state is BackupAuth) {
          DialogController.dismiss(context);
          showModalBottomSheet(
            isScrollControlled: true,
            context: context,
            shape: bottomSheetShape,
            builder: (BuildContext ctx) {
              return Wrap(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 40.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        RepaintBoundary(
                          key: this.globalKey,
                          child: QrImage(
                            data: state.wallet,
                            version: QrVersions.auto,
                            size: 240.0,
                          ),
                        ),
                        SizedBox(height: 40.0),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: SecondaryButton(
                            t('save_image'),
                            () {
                              RenderRepaintBoundary boundary = this
                                  .globalKey
                                  .currentContext
                                  .findRenderObject();

                              _backupBloc.add(Backup(boundary));
                              this._clickedBackup = true;
                              Navigator.of(context).pop();
                            },
                            textColor: Theme.of(context).primaryColor,
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              );
            },
          ).then((value) {
            if (!this._clickedBackup) {
              _backupBloc.add(CleanBackup());
            }

            this._clickedBackup = false;
          });
        }

        if (state is BackupDenied) {
          DialogController.dismiss(context);
          DialogController.show(context, ErrorDialog(t('error_password')));
        }

        if (state is BackupFail) {
          DialogController.show(context, ErrorDialog(t('error_backup')));
        }
      },
      child: BlocBuilder<BackupBloc, BackupState>(
        builder: (BuildContext ctx, BackupState state) {
          if (state is Backuped) {
            Color _color = Theme.of(context).accentColor;

            return Container(
              padding: const EdgeInsets.only(
                  right: 20.0, left: 4.0, top: 10.0, bottom: 10.0),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check,
                    color: _color,
                  ),
                  SizedBox(
                    width: 24.0,
                  ),
                  Text(
                    t('setting_backuped'),
                    style: TextStyle(color: _color),
                  ),
                ],
              ),
            );
          }

          return widget.item;
        },
      ),
    );
  }
}
