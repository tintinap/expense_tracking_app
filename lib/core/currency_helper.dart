import 'package:intl/intl.dart';

/// Currency codes supported by the app.
enum CurrencyCode {
  usd('USD', 'US Dollar', '\$'),
  eur('EUR', 'Euro', '€'),
  gbp('GBP', 'British Pound', '£'),
  jpy('JPY', 'Japanese Yen', '¥'),
  thb('THB', 'Thai Baht', '฿'),
  cny('CNY', 'Chinese Yuan', '¥'),
  ;

  final String code;
  final String name;
  final String symbol;
  const CurrencyCode(this.code, this.name, this.symbol);

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
}
