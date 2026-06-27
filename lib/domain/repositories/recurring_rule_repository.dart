import '../models/models.dart';

abstract class RecurringRuleRepository {
  Stream<List<RecurringRule>> watchAllRules();
  Future<List<RecurringRule>> getAllRules();
  Future<void> addRule(RecurringRule rule);
  Future<void> updateRule(RecurringRule rule);
  Future<void> deleteRule(String id);
}
