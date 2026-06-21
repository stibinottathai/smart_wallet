import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/proactive_insight.dart' as domain;
import '../services/database.dart';

// The Drift-generated row type is also called ProactiveInsight.
// We alias our domain model to avoid collision.
typedef DomainInsight = domain.ProactiveInsight;

class ProactiveInsightRepository {
  final AppDatabase _db;
  ProactiveInsightRepository(this._db);

  /// Stream of non-dismissed insights, newest first.
  Stream<List<DomainInsight>> watchActiveInsights() {
    return (_db.select(_db.proactiveInsights)
          ..where((t) => t.dismissed.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_rowToModel).toList());
  }

  /// Inserts a new insight, or updates the existing undismissed one with
  /// the same (triggerType, category) pair so duplicates don't stack.
  Future<void> upsertInsight(DomainInsight insight) async {
    // Find existing undismissed insight with the same trigger + category
    final existing = await (_db.select(_db.proactiveInsights)
          ..where((t) =>
              t.triggerType.equals(insight.triggerType) &
              t.dismissed.equals(false) &
              (insight.category != null
                  ? t.category.equals(insight.category!)
                  : t.category.isNull())))
        .getSingleOrNull();

    if (existing != null) {
      // Update message/tone/action in place
      await (_db.update(_db.proactiveInsights)
            ..where((t) => t.id.equals(existing.id)))
          .write(ProactiveInsightsCompanion(
        message: Value(insight.message),
        tone: Value(insight.tone.name),
        suggestedAction: Value(insight.suggestedAction),
        actionLabel: Value(insight.actionLabel),
        createdAt: Value(insight.createdAt),
      ));
    } else {
      await _db.into(_db.proactiveInsights).insert(
            ProactiveInsightsCompanion.insert(
              id: insight.id.isEmpty ? const Uuid().v4() : insight.id,
              createdAt: insight.createdAt,
              triggerType: insight.triggerType,
              category: Value(insight.category),
              message: insight.message,
              tone: insight.tone.name,
              suggestedAction: Value(insight.suggestedAction),
              actionLabel: Value(insight.actionLabel),
            ),
          );
    }
  }

  Future<void> dismissInsight(String id) async {
    await (_db.update(_db.proactiveInsights)
          ..where((t) => t.id.equals(id)))
        .write(const ProactiveInsightsCompanion(dismissed: Value(true)));
  }

  Future<void> clearAll() async {
    await _db.delete(_db.proactiveInsights).go();
  }

  DomainInsight _rowToModel(ProactiveInsight row) {
    return DomainInsight(
      id: row.id,
      createdAt: row.createdAt,
      triggerType: row.triggerType,
      category: row.category,
      message: row.message,
      tone: domain.InsightTone.fromString(row.tone),
      suggestedAction: row.suggestedAction,
      actionLabel: row.actionLabel,
      dismissed: row.dismissed,
    );
  }
}
