import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/database/daos/exchange_rate_dao.dart';

/// Result of a 3-tier exchange rate lookup
class ExchangeRateResult {
  final double rate;
  final String date;
  final String source; // 'local' | 'server' | 'frankfurter'
  final bool estimated;

  const ExchangeRateResult({
    required this.rate,
    required this.date,
    required this.source,
    this.estimated = false,
  });
}

/// Repository that implements the 3-tier exchange rate resolution:
///
/// 1. **Local DB** (Drift/SQLite) — fastest, works offline
/// 2. **Backend server** (NestJS → Postgres → Frankfurter) — centralized cache
/// 3. **Direct Frankfurter API** — fallback when BE is down
///
/// After fetching, rates are cached locally and synced back to BE.
class ExchangeRateRepository {
  final ExchangeRateDao _dao;
  final Dio _dio; // authenticated Dio for BE calls

  static const _frankfurterBaseUrl = 'https://api.frankfurter.app';

  ExchangeRateRepository({
    required ExchangeRateDao dao,
    required Dio dio,
  })  : _dao = dao,
        _dio = dio;

  /// Fetch recommended exchange rate using the 3-tier strategy.
  ///
  /// [baseCurrency] — the "1 of" currency (e.g. AUD)
  /// [quoteCurrency] — the "how many" currency (e.g. THB)
  /// [date] — the target date for the rate
  ///
  /// Returns: rate where 1 [baseCurrency] = [rate] [quoteCurrency]
  Future<ExchangeRateResult> getRecommendedRate({
    required String baseCurrency,
    required String quoteCurrency,
    required DateTime date,
  }) async {
    // Same currency → 1:1
    if (baseCurrency == quoteCurrency) {
      return ExchangeRateResult(
        rate: 1.0,
        date: _formatDate(date),
        source: 'local',
      );
    }

    // === Tier 1: Local DB ===
    final localRate = await _dao.getRate(baseCurrency, quoteCurrency, date);
    if (localRate != null) {
      return ExchangeRateResult(
        rate: localRate.rate,
        date: _formatDate(localRate.rateDate),
        source: 'local',
      );
    }

    // === Tier 2: Backend Server ===
    try {
      final dateStr = _formatDate(date);
      final response = await _dio.get(
        '/exchange-rates/$dateStr',
        queryParameters: {'from': baseCurrency, 'to': quoteCurrency},
      );

      if (response.statusCode == 200 && response.data != null) {
        final rate = (response.data['rate'] as num).toDouble();
        final actualDate = response.data['date'] as String;

        // Cache to local DB
        await _cacheLocally(
          baseCurrency, quoteCurrency, actualDate, rate, 'server',
        );

        return ExchangeRateResult(
          rate: rate,
          date: actualDate,
          source: 'server',
          estimated: response.data['estimated'] == true,
        );
      }
    } on DioException {
      // BE is down or unreachable → fall through to Tier 3
    }

    // === Tier 3: Direct Frankfurter API (fallback) ===
    try {
      final publicDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));

      final dateStr = _formatDate(date);
      final response = await publicDio.get(
        '$_frankfurterBaseUrl/$dateStr',
        queryParameters: {'from': baseCurrency, 'to': quoteCurrency},
      );

      if (response.data != null &&
          response.data['rates'] != null &&
          response.data['rates'][quoteCurrency] != null) {
        final rate = (response.data['rates'][quoteCurrency] as num).toDouble();
        final actualDate = response.data['date'] as String;

        // Cache to local DB
        await _cacheLocally(
          baseCurrency, quoteCurrency, actualDate, rate, 'frankfurter',
        );

        // Fire-and-forget: sync to BE for other devices/users
        _trySyncToBackend(baseCurrency, quoteCurrency, actualDate, rate);

        return ExchangeRateResult(
          rate: rate,
          date: actualDate,
          source: 'frankfurter',
        );
      }
    } catch (_) {
      // Both BE and Frankfurter failed (e.g. unsupported currency like VND)
    }

    // === Tier 4: Direct open.er-api.com (ultimate fallback for unsupported currencies) ===
    try {
      final publicDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));

      final response = await publicDio.get('https://open.er-api.com/v6/latest/$baseCurrency');

      if (response.data != null &&
          response.data['rates'] != null &&
          response.data['rates'][quoteCurrency] != null) {
        final rate = (response.data['rates'][quoteCurrency] as num).toDouble();
        final now = DateTime.now();
        final actualDate = _formatDate(now);

        // Cache to local DB
        await _cacheLocally(
          baseCurrency, quoteCurrency, actualDate, rate, 'open-er-api',
        );

        // Fire-and-forget: sync to BE for other devices/users
        _trySyncToBackend(baseCurrency, quoteCurrency, actualDate, rate);

        return ExchangeRateResult(
          rate: rate,
          date: actualDate,
          source: 'open-er-api',
        );
      }
    } catch (_) {
      // All tiers failed
    }

    // All tiers failed
    throw Exception('Unable to fetch exchange rate. Please try again.');
  }

  /// Insert or update the rate in the local Drift DB
  Future<void> _cacheLocally(
    String baseCurrency,
    String quoteCurrency,
    String dateStr,
    double rate,
    String source,
  ) async {
    final date = DateTime.parse(dateStr);
    final normalised = DateTime(date.year, date.month, date.day);

    await _dao.cacheRate(ExchangeRatesCompanion.insert(
      id: 'er-$baseCurrency-$quoteCurrency-${normalised.millisecondsSinceEpoch}',
      baseCurrency: baseCurrency,
      quoteCurrency: quoteCurrency,
      rateDate: normalised,
      rate: rate,
      source: Value(source),
    ));
  }

  /// Try to POST the rate to the BE so it's cached in Postgres too.
  /// Fire-and-forget — if BE is still down, this silently fails.
  void _trySyncToBackend(
    String baseCurrency,
    String quoteCurrency,
    String dateStr,
    double rate,
  ) {
    _dio
        .post('/exchange-rates', data: {
          'from': baseCurrency,
          'to': quoteCurrency,
          'date': dateStr,
          'rate': rate,
        })
        .ignore();
  }

  /// Format DateTime as YYYY-MM-DD string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
