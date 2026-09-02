import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/providers/database_providers.dart';
import '../services/fcm_token_service.dart';
import '../../sync/providers/sync_provider.dart';

const _storage = FlutterSecureStorage();

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

final fcmTokenServiceProvider = Provider<FcmTokenService>((ref) {
  final dio = ref.watch(dioProvider);
  return FcmTokenService(dio);
});

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final String? authProvider;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.authProvider,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    String? authProvider,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      authProvider: authProvider ?? this.authProvider,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(const AuthState(isLoading: true)) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final token = await _storage.read(key: 'access_token');
      // Ignore placeholder mock tokens from development
      final isValid = token != null &&
          token.isNotEmpty &&
          !token.startsWith('mock_');
      state = state.copyWith(isAuthenticated: isValid, isLoading: false);
    } catch (e) {
      state = state.copyWith(isAuthenticated: false, isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) {
        state = state.copyWith(isLoading: false);
        return; // User canceled
      }
      
      final auth = await account.authentication;
      if (auth.idToken == null) {
        throw Exception('Missing Google ID Token');
      }

      final dio = _ref.read(dioProvider);
      final response = await dio.post('/auth/google', data: {
        'idToken': auth.idToken,
        'email': account.email,
        'displayName': account.displayName ?? '',
        'avatarUrl': account.photoUrl,
        'providerId': account.id,
      });

      final data = response.data;
      await _storage.write(key: 'access_token', value: data['accessToken']);
      await _storage.write(key: 'refresh_token', value: data['refreshToken']);
      
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        authProvider: 'google',
      );
      await _ref.read(fcmTokenServiceProvider).registerCurrentToken();
      // Trigger initial sync
      await _ref.read(syncProvider.notifier).pushAllLocalRecords();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Google sign-in failed: ${e.toString()}');
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (credential.identityToken == null) {
        throw Exception('Missing Apple Identity Token');
      }

      final dio = _ref.read(dioProvider);
      final response = await dio.post('/auth/apple', data: {
        'identityToken': credential.identityToken,
        'email': credential.email ?? '',
        'displayName': [credential.givenName, credential.familyName]
            .where((e) => e != null)
            .join(' '),
        'providerId': credential.userIdentifier,
      });

      final data = response.data;
      await _storage.write(key: 'access_token', value: data['accessToken']);
      await _storage.write(key: 'refresh_token', value: data['refreshToken']);

      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        authProvider: 'apple',
      );
      await _ref.read(fcmTokenServiceProvider).registerCurrentToken();
      // Trigger initial sync
      await _ref.read(syncProvider.notifier).pushAllLocalRecords();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Apple sign-in failed: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _ref.read(fcmTokenServiceProvider).unregisterCurrentToken();
    } catch (_) {}
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    state = const AuthState(isAuthenticated: false, isLoading: false, authProvider: null);
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final dio = _ref.read(dioProvider);
      await dio.delete('/auth/account');
      try {
        await _ref.read(fcmTokenServiceProvider).unregisterCurrentToken();
      } catch (_) {}
      
      // Clear local database
      final db = _ref.read(databaseProvider);
      await db.clearAllData();

      // Clear tokens
      await _storage.delete(key: 'access_token');
      await _storage.delete(key: 'refresh_token');
      
      state = const AuthState(isAuthenticated: false, isLoading: false, authProvider: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Account deletion failed: ${e.toString()}');
    }
  }
}
