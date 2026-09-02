import 'package:daily_spend/features/sync/providers/sync_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldApplyRemoteLww', () {
    test('returns true when remote updatedAt is newer', () {
      final local = DateTime(2026, 1, 1, 10, 0, 0);
      final remote = DateTime(2026, 1, 1, 11, 0, 0);

      expect(shouldApplyRemoteLww(local, remote), isTrue);
    });

    test('returns false when remote updatedAt is not newer', () {
      final local = DateTime(2026, 1, 1, 10, 0, 0);
      final remote = DateTime(2026, 1, 1, 10, 0, 0);

      expect(shouldApplyRemoteLww(local, remote), isFalse);
    });
  });
}
