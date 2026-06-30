import '../../domain/models/models.dart';
import '../../domain/repositories/transfer_repository.dart';

/// Keeps a pair of auto-managed [Transfer]s in sync with each [Investment]:
///
///  * `inv_buy_<id>`  — moves the cost basis from the funding account into the
///    hidden [investmentAccountId] wallet the moment the holding is recorded.
///  * `inv_sell_<id>` — moves the proceeds (at current value) back to the
///    funding account when the holding is marked closed.
///
/// Mid-life value updates do **not** touch any account — unrealized gains
/// shouldn't move cash. The deterministic ids make sync idempotent and let the
/// existing CSV-import upsert logic round-trip cleanly without double-posting.
class InvestmentTransferService {
  /// Id of the system wallet that holds the cost basis of all active
  /// investments. Seeded by the v14 migration and on fresh installs.
  static const String investmentAccountId = 'acc_investments';

  /// Stable id for the auto-managed "buy" transfer of [investmentId].
  static String buyTransferId(String investmentId) => 'inv_buy_$investmentId';

  /// Stable id for the auto-managed "sell" transfer of [investmentId].
  static String sellTransferId(String investmentId) => 'inv_sell_$investmentId';

  /// True when [transferId] is one of the auto-managed investment transfers.
  /// Useful to dim / lock these rows in the transfers UI later if desired.
  static bool isInvestmentTransfer(String transferId) =>
      transferId.startsWith('inv_buy_') || transferId.startsWith('inv_sell_');

  final TransferRepository _transfers;

  InvestmentTransferService(this._transfers);

  /// Reconciles auto-transfers to match the post-save state of [investment].
  /// Call this after every add / update from the form. [previous] is the
  /// pre-edit snapshot (null for a new investment) and lets us catch the case
  /// where a funding account was removed or swapped — we still need to delete
  /// the old transfer even if no new one will be created.
  Future<void> syncOnSave({
    required Investment investment,
    Investment? previous,
  }) async {
    final existing = {for (final t in await _transfers.getAllTransfers()) t.id: t};

    await _reconcileBuy(investment, existing);
    await _reconcileSell(investment, existing);

    // If the funding account was wiped between previous and new state and the
    // new state has no account at all, the helpers above already deleted the
    // stale rows. Nothing extra to do here.
    final _ = previous;
  }

  /// Removes both auto-transfers associated with [investmentId]. Call this
  /// when the investment row is being deleted; the transfer-history reflects
  /// the reversal automatically.
  Future<void> syncOnDelete(String investmentId) async {
    final ids = {buyTransferId(investmentId), sellTransferId(investmentId)};
    final existing = await _transfers.getAllTransfers();
    for (final t in existing.where((t) => ids.contains(t.id))) {
      await _transfers.deleteTransfer(t.id);
    }
  }

  Future<void> _reconcileBuy(
    Investment inv,
    Map<String, Transfer> existing,
  ) async {
    final id = buyTransferId(inv.id);
    final fundingId = inv.accountId;
    // No funding account picked → no auto-transfer (user opted out of the
    // automatic balance impact). Remove any stale one.
    if (fundingId == null || fundingId.isEmpty || fundingId == investmentAccountId) {
      if (existing.containsKey(id)) await _transfers.deleteTransfer(id);
      return;
    }

    final desired = Transfer(
      id: id,
      fromAccountId: fundingId,
      toAccountId: investmentAccountId,
      amount: inv.investedAmount,
      date: inv.purchaseDate,
      note: 'Investment: ${inv.name}',
    );

    final current = existing[id];
    if (current == null) {
      await _transfers.addTransfer(desired);
    } else if (!_sameTransfer(current, desired)) {
      await _transfers.updateTransfer(desired);
    }
  }

  Future<void> _reconcileSell(
    Investment inv,
    Map<String, Transfer> existing,
  ) async {
    final id = sellTransferId(inv.id);
    final fundingId = inv.accountId;
    // Sell transfer only exists when the holding has been closed AND there's
    // a destination account to credit the proceeds back to.
    final shouldExist = inv.isClosed &&
        fundingId != null &&
        fundingId.isNotEmpty &&
        fundingId != investmentAccountId;

    if (!shouldExist) {
      if (existing.containsKey(id)) await _transfers.deleteTransfer(id);
      return;
    }

    final desired = Transfer(
      id: id,
      fromAccountId: investmentAccountId,
      toAccountId: fundingId,
      amount: inv.currentValue,
      // Use the last-value-update time when known so the sell lands at the
      // moment the closing price was recorded; otherwise the purchase date is
      // the most reasonable fallback we have.
      date: inv.lastValueUpdate ?? DateTime.now(),
      note: 'Investment proceeds: ${inv.name}',
    );

    final current = existing[id];
    if (current == null) {
      await _transfers.addTransfer(desired);
    } else if (!_sameTransfer(current, desired)) {
      await _transfers.updateTransfer(desired);
    }
  }

  bool _sameTransfer(Transfer a, Transfer b) {
    return a.fromAccountId == b.fromAccountId &&
        a.toAccountId == b.toAccountId &&
        a.amount == b.amount &&
        a.date == b.date &&
        a.note == b.note;
  }
}
