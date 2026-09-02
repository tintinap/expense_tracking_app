import 'package:daily_spend/features/auth/services/fcm_token_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FcmTokenService', () {
    test('registerCurrentToken calls register override with token', () async {
      String? capturedToken;
      final service = FcmTokenService(
        Dio(),
        getToken: () async => 'token-123',
        registerOverride: (token) async {
          capturedToken = token;
        },
      );

      await service.registerCurrentToken();

      expect(capturedToken, 'token-123');
    });

    test('registerCurrentToken skips when token is null', () async {
      var called = false;
      final service = FcmTokenService(
        Dio(),
        getToken: () async => null,
        registerOverride: (_) async {
          called = true;
        },
      );

      await service.registerCurrentToken();

      expect(called, isFalse);
    });

    test('unregisterCurrentToken calls unregister override', () async {
      var called = false;
      final service = FcmTokenService(
        Dio(),
        unregisterOverride: () async {
          called = true;
        },
      );

      await service.unregisterCurrentToken();

      expect(called, isTrue);
    });
  });
}
