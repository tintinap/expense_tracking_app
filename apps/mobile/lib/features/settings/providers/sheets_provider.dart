import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class SheetsState {
  final bool isLoading;
  final bool isConnected;
  final String? error;
  final String? syncStatus;

  SheetsState({
    this.isLoading = false,
    this.isConnected = false,
    this.error,
    this.syncStatus,
  });

  SheetsState copyWith({
    bool? isLoading,
    bool? isConnected,
    String? error,
    String? syncStatus,
  }) {
    return SheetsState(
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      error: error,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class SheetsNotifier extends StateNotifier<SheetsState> {
  final Ref ref;
  final Dio dio;

  SheetsNotifier(this.ref, this.dio) : super(SheetsState()) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await dio.get('/sheets/status');
      if (res.statusCode == 200) {
        final connected = res.data['connected'] == true || res.data['enabled'] == true;
        state = state.copyWith(
          isLoading: false,
          isConnected: connected,
          syncStatus: res.data['spreadsheetId'] != null ? 'Synced' : 'Not setup',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> connect() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await dio.post('/sheets/setup');
      if (res.statusCode == 200 || res.statusCode == 201) {
        state = state.copyWith(isLoading: false, isConnected: true);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> disconnect() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      try {
        await dio.delete('/sheets/disconnect');
      } on DioException catch (e) {
        if (e.response?.statusCode != 404 && e.response?.statusCode != 405) {
          rethrow;
        }
        await dio.post('/sheets/disconnect');
      }
      state = state.copyWith(isLoading: false, isConnected: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final sheetsProvider = StateNotifierProvider<SheetsNotifier, SheetsState>((ref) {
  final dio = ref.watch(dioProvider);
  return SheetsNotifier(ref, dio);
});
