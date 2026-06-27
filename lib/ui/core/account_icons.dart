import 'package:flutter/material.dart';
import 'package:smart_wallet/domain/models/models.dart' as domain;

/// Maps an [domain.AccountType] to its representative icon. Kept in one place so
/// the accounts screen, dashboard and pickers stay visually consistent.
IconData getAccountIcon(domain.AccountType type) {
  switch (type) {
    case domain.AccountType.cash:
      return Icons.payments_rounded;
    case domain.AccountType.bank:
      return Icons.account_balance_rounded;
    case domain.AccountType.card:
      return Icons.credit_card_rounded;
    case domain.AccountType.upi:
      return Icons.qr_code_rounded;
    case domain.AccountType.wallet:
      return Icons.account_balance_wallet_rounded;
    case domain.AccountType.other:
      return Icons.savings_rounded;
  }
}
