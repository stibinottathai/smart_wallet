import 'package:flutter/material.dart';

/// Maps a stored category icon name to its [IconData].
///
/// Shared across the dashboard, bills, budgets and transaction views so the
/// icon mapping stays consistent in one place.
IconData getCategoryIcon(String? iconName) {
  switch (iconName) {
    case 'restaurant':
      return Icons.restaurant;
    case 'shopping_basket':
      return Icons.shopping_basket;
    case 'directions_car':
      return Icons.directions_car;
    case 'home':
      return Icons.home;
    case 'movie':
      return Icons.movie;
    case 'power':
      return Icons.power;
    case 'attach_money':
      return Icons.attach_money;
    default:
      return Icons.help_outline;
  }
}
