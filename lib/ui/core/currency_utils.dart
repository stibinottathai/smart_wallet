import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, String> currencySymbols = {
  'AED': 'د.إ ',
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'INR': '₹',
  'SAR': '﷼ ',
  'QAR': '﷼ ',
  'KWD': 'د.ك ',
  'OMR': '﷼ ',
  'BHD': 'د.ب ',
  'JPY': '¥',
  'CNY': '¥',
};

const List<String> supportedCurrencies = [
  'AED',
  'USD',
  'EUR',
  'GBP',
  'INR',
  'SAR',
  'QAR',
  'KWD',
  'OMR',
  'BHD',
  'JPY',
  'CNY',
];

String _initialCurrency = 'AED';

Future<void> loadCurrencyPref() async {
  final prefs = await SharedPreferences.getInstance();
  _initialCurrency = prefs.getString('currency_code') ?? 'AED';
}

final currencyCodeProvider = StateProvider<String>((ref) => _initialCurrency);

Future<void> saveCurrencyPref(String code) async {
  _initialCurrency = code;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('currency_code', code);
}

String currencySymbol(String code) => currencySymbols[code] ?? '\$';
