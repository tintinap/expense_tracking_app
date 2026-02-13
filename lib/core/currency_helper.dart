import 'package:intl/intl.dart';

/// Currency codes supported by the app (all supported by Frankfurter for rates).
enum CurrencyCode {
  usd('USD', 'US Dollar', '\$'),
  eur('EUR', 'Euro', '€'),
  gbp('GBP', 'British Pound', '£'),
  jpy('JPY', 'Japanese Yen', '¥'),
  thb('THB', 'Thai Baht', '฿'),
  cny('CNY', 'Chinese Yuan', '¥'),
  aud('AUD', 'Australian Dollar', 'A\$'),
  cad('CAD', 'Canadian Dollar', 'C\$'),
  chf('CHF', 'Swiss Franc', 'CHF'),
  inr('INR', 'Indian Rupee', '₹'),
  sgd('SGD', 'Singapore Dollar', 'S\$'),
  krw('KRW', 'South Korean Won', '₩'),
  ;

  final String code;
  final String name;
  final String symbol;
  const CurrencyCode(this.code, this.name, this.symbol);

  static CurrencyCode? fromCode(String code) {
    final upper = code.toUpperCase();
    for (final c in CurrencyCode.values) {
      if (c.code == upper) return c;
    }
    return null;
  }

  NumberFormat get formatter => NumberFormat.currency(
        locale: 'en_US',
        symbol: symbol,
        decimalDigits: code == 'JPY' ? 0 : 2,
      );

  String format(num amount) => formatter.format(amount);

  String formatSigned(double amount) {
    final formatted = formatter.format(amount.abs());
    return amount >= 0 ? '+$formatted' : '-$formatted';
  }

  /// Format amount in a given currency code. Falls back to "CODE amount" if unknown.
  static String formatSignedInCurrency(double amount, String currencyCode) {
    final c = fromCode(currencyCode);
    if (c != null) return c.formatSigned(amount);
    final abs = amount.abs();
    final sign = amount >= 0 ? '+' : '-';
    return '$sign$abs $currencyCode';
  }
}
