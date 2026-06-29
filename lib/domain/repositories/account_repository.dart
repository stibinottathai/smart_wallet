import '../models/models.dart';

abstract class AccountRepository {
  Stream<List<Account>> watchAllAccounts();
  Future<List<Account>> getAllAccounts();
  Future<void> addAccount(Account account);
  Future<void> updateAccount(Account account);
  Future<void> deleteAccount(String id);
  Future<void> setDefaultAccount(String id);
}
