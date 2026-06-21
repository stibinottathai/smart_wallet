import '../models/models.dart';

abstract class HealthScoreRepository {
  Future<void> saveSnapshot(FinancialHealthScore score, String month);
  Future<FinancialHealthScore?> getSnapshot(String month);
  Future<List<({String month, double score})>> getAllSnapshots();
}
