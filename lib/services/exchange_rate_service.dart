import 'dart:convert';

import 'package:http/http.dart' as http;

/// Exchange rates from Frankfurter API (ECB-backed, free, no API key).
/// Similar data quality to Google Finance - updated daily.
class ExchangeRateService {
  static const _baseUrl = 'https://api.frankfurter.dev/v1';

  static final Map<String, double?> _cache = {};

  /// Convert amount from [fromCurrency] to [toCurrency] using rate on [date].
  /// Returns null if rate unavailable (network error or unsupported currency).
  static Future<double?> convert({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
    required DateTime date,
  }) async {
    if (fromCurrency == toCurrency) return amount;

    final cacheKey = '${fromCurrency}_${toCurrency}_${_dateKey(date)}';
    final rate = _cache[cacheKey] ??= await _fetchRate(fromCurrency, toCurrency, date);
    if (rate == null) return null;

    return amount * rate;
  }

  /// Get exchange rate from [fromCurrency] to [toCurrency] on [date].
  /// Returns 1.0 if same currency, null if unavailable.
  static Future<double?> getRate({
    required String fromCurrency,
    required String toCurrency,
    required DateTime date,
  }) async {
    if (fromCurrency == toCurrency) return 1.0;
    final cacheKey = '${fromCurrency}_${toCurrency}_${_dateKey(date)}';
    return _cache[cacheKey] ??= await _fetchRate(fromCurrency, toCurrency, date);
  }

  static Future<double?> _fetchRate(String from, String to, DateTime date) async {
    try {
      final dateStr = _dateKey(date);
      final uri = Uri.parse('$_baseUrl/$dateStr?base=$from&symbols=$to');
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('', 408),
      );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final rates = json['rates'] as Map<String, dynamic>?;
      if (rates == null || !rates.containsKey(to)) return null;

      final value = rates[to];
      if (value is num) return value.toDouble();
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Clear cache (e.g. when user wants fresh rates).
  static void clearCache() => _cache.clear();
}
