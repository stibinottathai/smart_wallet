import '../models/models.dart';

abstract class DebtRepository {
  Stream<List<Debt>> watchAllDebts();
  Future<List<Debt>> getAllDebts();
  Future<void> addDebt(Debt debt);
  Future<void> updateDebt(Debt debt);
  Future<void> deleteDebt(String id);
}
