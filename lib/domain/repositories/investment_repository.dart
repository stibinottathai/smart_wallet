import '../models/models.dart';

abstract class InvestmentRepository {
  Stream<List<Investment>> watchAllInvestments();
  Future<List<Investment>> getAllInvestments();
  Future<void> addInvestment(Investment investment);
  Future<void> updateInvestment(Investment investment);
  Future<void> deleteInvestment(String id);
}
