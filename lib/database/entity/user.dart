import 'package:floor/floor.dart';

@entity
class User {
  @primaryKey
  @ColumnInfo(name: 'user_id')
  final String userId;

  final String keystore;

  @ColumnInfo(name: 'password_hash')
  final String passwordHash;

  @ColumnInfo(name: 'password_salt')
  final String passwordSalt;

  @ColumnInfo(name: 'backup_status', nullable: false)
  final bool backupStatus;

  User(this.userId, this.keystore, this.passwordHash, this.passwordSalt,
      this.backupStatus);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          keystore == other.keystore;

  @override
  int get hashCode => userId.hashCode ^ keystore.hashCode;
}