import '../../domain/models/models.dart';

class CategoryPredictor {
  static String predict(String merchant, List<Category> availableCategories, bool isExpense) {
    if (availableCategories.isEmpty) {
      return 'cat_uncategorized';
    }

    if (!isExpense) {
      final incomeCat = availableCategories.firstWhere(
        (c) => c.id == 'cat_income' || c.name.toLowerCase().contains('income') || c.name.toLowerCase().contains('salary'),
        orElse: () => availableCategories.first,
      );
      return incomeCat.id;
    }

    final cleaned = merchant.toLowerCase();

    // Map keywords to standard categories
    String targetGroup;
    if (cleaned.contains('swiggy') || cleaned.contains('zomato') || cleaned.contains('restaurant') || cleaned.contains('food') || cleaned.contains('dining') || cleaned.contains('cafe') || cleaned.contains('starbucks')) {
      targetGroup = 'dining';
    } else if (cleaned.contains('uber') || cleaned.contains('ola') || cleaned.contains('transport') || cleaned.contains('cab') || cleaned.contains('fuel') || cleaned.contains('petrol') || cleaned.contains('indian oil') || cleaned.contains('hpcl') || cleaned.contains('bpcl') || cleaned.contains('metro') || cleaned.contains('irctc')) {
      targetGroup = 'transport';
    } else if (cleaned.contains('amazon') || cleaned.contains('flipkart') || cleaned.contains('shopping') || cleaned.contains('myntra') || cleaned.contains('reliance digital') || cleaned.contains('croma')) {
      targetGroup = 'shopping';
    } else if (cleaned.contains('grocery') || cleaned.contains('groceries') || cleaned.contains('blinkit') || cleaned.contains('jiomart') || cleaned.contains('supermarket') || cleaned.contains('dmart')) {
      targetGroup = 'groceries';
    } else if (cleaned.contains('rent') || cleaned.contains('housing') || cleaned.contains('pg') || cleaned.contains('maintenance') || cleaned.contains('society')) {
      targetGroup = 'housing';
    } else if (cleaned.contains('netflix') || cleaned.contains('spotify') || cleaned.contains('movie') || cleaned.contains('entertainment') || cleaned.contains('cinema') || cleaned.contains('theatre') || cleaned.contains('bookmyshow') || cleaned.contains('hotstar') || cleaned.contains('youtube premium')) {
      targetGroup = 'entertainment';
    } else if (cleaned.contains('electricity') || cleaned.contains('water') || cleaned.contains('power') || cleaned.contains('gas') || cleaned.contains('internet') || cleaned.contains('bill') || cleaned.contains('recharge') || cleaned.contains('broadband') || cleaned.contains('jio') || cleaned.contains('airtel') || cleaned.contains('vi ')) {
      targetGroup = 'utilities';
    } else if (cleaned.contains('hospital') || cleaned.contains('medical') || cleaned.contains('doctor') || cleaned.contains('healthcare') || cleaned.contains('pharmacy') || cleaned.contains('medicine') || cleaned.contains('apollo') || cleaned.contains('pharmeasy')) {
      targetGroup = 'healthcare';
    } else if (cleaned.contains('loan') || cleaned.contains('debt') || cleaned.contains('emi') || cleaned.contains('interest') || cleaned.contains('mortgage')) {
      targetGroup = 'loans';
    } else {
      targetGroup = 'uncategorized';
    }

    // Match keywords to available categories
    for (final cat in availableCategories) {
      final name = cat.name.toLowerCase();
      final id = cat.id.toLowerCase();

      if (targetGroup == 'dining' && (id.contains('dining') || name.contains('dining') || name.contains('food') || name.contains('drink') || name.contains('restaurant'))) {
        return cat.id;
      }
      if (targetGroup == 'transport' && (id.contains('transport') || name.contains('transport') || name.contains('car') || name.contains('travel') || name.contains('fuel') || name.contains('petrol'))) {
        return cat.id;
      }
      if (targetGroup == 'shopping' && (id.contains('shopping') || name.contains('shopping') || name.contains('shop') || name.contains('store'))) {
        return cat.id;
      }
      if (targetGroup == 'groceries' && (id.contains('grocery') || id.contains('groceries') || name.contains('grocery') || name.contains('groceries') || name.contains('mart'))) {
        return cat.id;
      }
      if (targetGroup == 'housing' && (id.contains('housing') || id.contains('rent') || name.contains('housing') || name.contains('rent') || name.contains('home'))) {
        return cat.id;
      }
      if (targetGroup == 'entertainment' && (id.contains('entertainment') || name.contains('entertainment') || name.contains('movie') || name.contains('show') || name.contains('play'))) {
        return cat.id;
      }
      if (targetGroup == 'utilities' && (id.contains('utilities') || name.contains('utilities') || name.contains('bill') || name.contains('electricity') || name.contains('power'))) {
        return cat.id;
      }
      if (targetGroup == 'healthcare' && (id.contains('healthcare') || id.contains('hospital') || name.contains('healthcare') || name.contains('hospital') || name.contains('medical') || name.contains('medicine'))) {
        return cat.id;
      }
      if (targetGroup == 'loans' && (id.contains('loans') || id.contains('debt') || name.contains('loan') || name.contains('debt') || name.contains('emi'))) {
        return cat.id;
      }
    }

    // Default to uncategorized if no target group matched, or search for Uncategorized category
    final uncategorized = availableCategories.firstWhere(
      (c) => c.id == 'cat_uncategorized' || c.name.toLowerCase().contains('uncategorized'),
      orElse: () => availableCategories.first,
    );
    return uncategorized.id;
  }
}
