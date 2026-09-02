import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FcmTokenService {
  final Dio _dio;
  final Future<String?> Function() _getToken;
  final Future<void> Function(String token)? _registerOverride;
  final Future<void> Function()? _unregisterOverride;

  FcmTokenService(
    this._dio, {
    Future<String?> Function()? getToken,
    Future<void> Function(String token)? registerOverride,
    Future<void> Function()? unregisterOverride,
  })  : _getToken = getToken ?? _defaultGetToken,
        _registerOverride = registerOverride,
        _unregisterOverride = unregisterOverride;

  static Future<String?> _defaultGetToken() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return null;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      return messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<void> registerCurrentToken() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      return;
    }
    if (_registerOverride != null) {
      await _registerOverride(token);
      return;
    }
    await _dio.post('/notifications/register-token', data: {'fcmToken': token});
  }

  Future<void> unregisterCurrentToken() async {
    if (_unregisterOverride != null) {
      await _unregisterOverride();
      return;
    }
    await _dio.delete('/notifications/unregister-token');
  }
}
