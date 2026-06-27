import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Fetches and caches foreign-exchange rates so transactions entered in a
/// foreign currency can be converted to the app's base currency.
///
/// Uses the free, key-less open.er-api.com endpoint. Rates are cached per
/// source currency in SharedPreferences for [_cacheTtl]; if the network is
/// unavailable the last cached rate is returned, and the UI always allows a
/// manual rate override so the feature works fully offline.
class CurrencyConversionService {
  static const Duration _cacheTtl = Duration(hours: 12);
  static const String _cachePrefix = 'fx_rates_';

  /// Returns how many units of [to] equal 1 unit of [from] (e.g. from USD to
  /// INR → ~83). Returns null if no rate is available (offline + no cache).
  Future<double?> fetchRate(String from, String to) async {
    if (from == to) return 1.0;
    final rates = await _ratesFor(from);
    final r = rates?[to];
    if (r == null) return null;
    return r.toDouble();
  }

  /// Convenience: convert [amount] in [from] to [to], or null if no rate.
  Future<double?> convert(double amount, String from, String to) async {
    final rate = await fetchRate(from, to);
    return rate == null ? null : amount * rate;
  }

  Future<Map<String, dynamic>?> _ratesFor(String from) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cachePrefix$from';

    // Serve fresh cache without hitting the network.
    final cached = prefs.getString(key);
    if (cached != null) {
      try {
        final decoded = jsonDecode(cached) as Map<String, dynamic>;
        final fetchedAt = DateTime.fromMillisecondsSinceEpoch(decoded['_ts'] as int);
        if (DateTime.now().difference(fetchedAt) < _cacheTtl) {
          return decoded['rates'] as Map<String, dynamic>;
        }
      } catch (_) {/* fall through to refetch */}
    }

    try {
      final res = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/$from'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['result'] == 'success' && body['rates'] is Map) {
          final rates = body['rates'] as Map<String, dynamic>;
          await prefs.setString(key, jsonEncode({'_ts': DateTime.now().millisecondsSinceEpoch, 'rates': rates}));
          return rates;
        }
      }
    } catch (_) {/* network/parse error → fall back to stale cache below */}

    // Network failed — return stale cache if we have any.
    if (cached != null) {
      try {
        return (jsonDecode(cached) as Map<String, dynamic>)['rates'] as Map<String, dynamic>;
      } catch (_) {}
    }
    return null;
  }
}
