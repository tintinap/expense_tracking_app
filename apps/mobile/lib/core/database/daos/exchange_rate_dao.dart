import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables.dart';

part 'exchange_rate_dao.g.dart';

/// PRD §20 — DAO for offline exchange rate cache
@DriftAccessor(tables: [ExchangeRates])
class ExchangeRateDao extends DatabaseAccessor<AppDatabase>
    with _$ExchangeRateDaoMixin {
  ExchangeRateDao(super.db);

  /// Get cached rate for specific date
  Future<ExchangeRateData?> getRate(
    String baseCurrency,
    String quoteCurrency,
    DateTime date,
  ) {
    // Normalise date to midnight for comparison
    final normalisedDate = DateTime(date.year, date.month, date.day);

    return (select(exchangeRates)
          ..where((r) =>
              r.baseCurrency.equals(baseCurrency) &
              r.quoteCurrency.equals(quoteCurrency) &
              r.rateDate.equals(normalisedDate)))
        .getSingleOrNull();
  }

  /// Get most recent rate (fallback)
  Future<ExchangeRateData?> getMostRecent(
    String baseCurrency,
    String quoteCurrency,
  ) {
    return (select(exchangeRates)
          ..where((r) =>
              r.baseCurrency.equals(baseCurrency) &
              r.quoteCurrency.equals(quoteCurrency))
          ..orderBy([(r) => OrderingTerm.desc(r.rateDate)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get rate at or near a specific date from DB cache only (no network).
  /// Returns null if no rate is cached for this pair at all.
  /// Priority: exact date → most recent cached.
  Future<double?> getForDateOrRecent(
    String baseCurrency,
    String quoteCurrency,
    DateTime date,
  ) async {
    if (baseCurrency == quoteCurrency) return 1.0;

    // Try exact date first
    final exact = await getRate(baseCurrency, quoteCurrency, date);
    if (exact != null && exact.rate > 0) return exact.rate;

    // Fall back to most recent cached — DB only, no network call
    final recent = await getMostRecent(baseCurrency, quoteCurrency);
    if (recent != null && recent.rate > 0) return recent.rate;

    return null; // Nothing cached — caller should hide the UI element
  }

  /// Get most recent rate or fallback to Frankfurter API
  Future<double> getMostRecentOrFetch(
    String baseCurrency,
    String quoteCurrency,
  ) async {
    if (baseCurrency == quoteCurrency) return 1.0;

    final cached = await getMostRecent(baseCurrency, quoteCurrency);
    if (cached != null && cached.rate > 0) return cached.rate;

    try {
      final publicDio = Dio();
      final res = await publicDio.get(
        'https://api.frankfurter.app/latest',
        queryParameters: {
          'from': baseCurrency,
          'to': quoteCurrency,
        },
      );

      if (res.data != null &&
          res.data['rates'] != null &&
          res.data['rates'][quoteCurrency] != null) {
        final rateValue = (res.data['rates'][quoteCurrency] as num).toDouble();
        final now = DateTime.now();
        final dateOnly = DateTime(now.year, now.month, now.day);

        await cacheRate(ExchangeRatesCompanion.insert(
          id: 'er-$baseCurrency-$quoteCurrency-${dateOnly.millisecondsSinceEpoch}',
          baseCurrency: baseCurrency,
          quoteCurrency: quoteCurrency,
          rateDate: dateOnly,
          rate: rateValue,
        ));

        return rateValue;
      }
    } catch (_) {
      // Frankfurter failed (unsupported currency or down). Try open.er-api.com fallback
    }

    try {
      final publicDio = Dio();
      final res = await publicDio.get('https://open.er-api.com/v6/latest/$baseCurrency');

      if (res.data != null &&
          res.data['rates'] != null &&
          res.data['rates'][quoteCurrency] != null) {
        final rateValue = (res.data['rates'][quoteCurrency] as num).toDouble();
        final now = DateTime.now();
        final dateOnly = DateTime(now.year, now.month, now.day);

        await cacheRate(ExchangeRatesCompanion.insert(
          id: 'er-$baseCurrency-$quoteCurrency-${dateOnly.millisecondsSinceEpoch}',
          baseCurrency: baseCurrency,
          quoteCurrency: quoteCurrency,
          rateDate: dateOnly,
          rate: rateValue,
        ));

        return rateValue;
      }
    } catch (_) {
      // Both failed. Silently swallow errors and return 1.0 as last resort.
    }
    return 1.0;
  }

  /// Cache a new rate
  Future<void> cacheRate(ExchangeRatesCompanion entry) {
    return into(exchangeRates).insertOnConflictUpdate(entry);
  }
}
