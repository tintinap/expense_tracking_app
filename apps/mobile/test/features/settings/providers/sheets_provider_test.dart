import 'dart:convert';

import 'package:daily_spend/core/network/dio_client.dart';
import 'package:daily_spend/features/settings/providers/sheets_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final ResponseBody Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }
}

ResponseBody _jsonBody(Object body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  group('SheetsNotifier', () {
    test('checkStatus maps connected contract', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == '/sheets/status') {
          return _jsonBody({'connected': true, 'spreadsheetId': 'abc'}, 200);
        }
        return _jsonBody({}, 404);
      });

      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      await container.read(sheetsProvider.notifier).checkStatus();
      final state = container.read(sheetsProvider);
      expect(state.isConnected, isTrue);
      expect(state.syncStatus, 'Synced');
    });

    test('disconnect uses DELETE endpoint', () async {
      var deleteCalled = false;
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == '/sheets/status') {
          return _jsonBody({'connected': true, 'spreadsheetId': 'abc'}, 200);
        }
        if (options.path == '/sheets/disconnect' && options.method == 'DELETE') {
          deleteCalled = true;
          return _jsonBody({'success': true}, 200);
        }
        return _jsonBody({}, 404);
      });

      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      final success = await container.read(sheetsProvider.notifier).disconnect();
      expect(success, isTrue);
      expect(deleteCalled, isTrue);
    });
  });
}
