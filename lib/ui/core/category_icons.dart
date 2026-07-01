import 'package:flutter/material.dart';

/// All icons available for user-created categories, keyed by their stored name.
const Map<String, IconData> kAllCategoryIcons = {
  'restaurant': Icons.restaurant,
  'shopping_basket': Icons.shopping_basket,
  'shopping_cart': Icons.shopping_cart,
  'directions_car': Icons.directions_car,
  'home': Icons.home,
  'movie': Icons.movie,
  'power': Icons.power,
  'attach_money': Icons.attach_money,
  'local_hospital': Icons.local_hospital,
  'account_balance': Icons.account_balance,
  'fitness_center': Icons.fitness_center,
  'school': Icons.school,
  'flight': Icons.flight,
  'phone': Icons.phone,
  'pets': Icons.pets,
  'card_giftcard': Icons.card_giftcard,
  'coffee': Icons.coffee,
  'work': Icons.work,
  'spa': Icons.spa,
  'savings': Icons.savings,
  'sports': Icons.sports,
  'child_care': Icons.child_care,
  'brush': Icons.brush,
  'wifi': Icons.wifi,
  'help_outline': Icons.help_outline,
  'payments': Icons.payments,
  'computer': Icons.computer,
  'business': Icons.business,
  'shopping_bag': Icons.shopping_bag,
  'trending_up': Icons.trending_up,
};

/// Maps a stored category icon name to its [IconData].
IconData getCategoryIcon(String? iconName) {
  return kAllCategoryIcons[iconName] ?? Icons.help_outline;
}
