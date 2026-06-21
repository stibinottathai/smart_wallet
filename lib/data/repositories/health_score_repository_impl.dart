import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/models.dart' as domain;
import '../../domain/repositories/health_score_repository.dart';
import '../services/database.dart';

class HealthScoreRepositoryImpl implements HealthScoreRepository {
  final AppDatabase _db;

  HealthScoreRepositoryImpl(this._db);

  @override
  Future<void> saveSnapshot(domain.FinancialHealthScore score, String month) async {
    final existing = await (_db.select(_db.healthScores)
      ..where((t) => t.month.equals(month))).get();

    if (existing.isNotEmpty) {
      await (_db.delete(_db.healthScores)
        ..where((t) => t.month.equals(month))).go();
    }

    await _db.into(_db.healthScores).insert(HealthScoresCompanion(
      id: Value(const Uuid().v4()),
      month: Value(month),
      score: Value(score.totalScore),
      breakdownJson: Value(jsonEncode(score.toJson())),
      createdAt: Value(DateTime.now()),
    ));
  }

  @override
  Future<domain.FinancialHealthScore?> getSnapshot(String month) async {
    final row = await (_db.select(_db.healthScores)
      ..where((t) => t.month.equals(month))).getSingleOrNull();
    if (row == null) return null;
    return domain.FinancialHealthScore.fromJson(
      jsonDecode(row.breakdownJson) as Map<String, dynamic>,
    );
  }

  @override
  Future<List<({String month, double score})>> getAllSnapshots() async {
    final rows = await (_db.select(_db.healthScores)
      ..orderBy([(t) => OrderingTerm(expression: t.month, mode: OrderingMode.desc)])).get();
    return rows.map((r) => (month: r.month, score: r.score)).toList();
  }
}
