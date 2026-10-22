import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/api_models.dart';
import '../providers.dart';
import 'token_storage.dart';

class AuthState {
  const AuthState({
    this.user,
    this.loading = false,
    this.initialized = false,
    this.error,
  });

  final User? user;
  final bool loading;
  final bool initialized;
  final String? error;

  bool get isAuthenticated => user != null;
  bool get mustChangePassword => user?.mustChangePassword == true;
  bool get isAdmin => user?.role.isAdmin == true;
  bool get isUser => user?.role == UserRole.user;

  AuthState copyWith({
    User? user,
    bool? loading,
    bool? initialized,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        loading: loading ?? this.loading,
        initialized: initialized ?? this.initialized,
        error: clearError ? null : (error ?? this.error),
      );
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  ApiClient get _api => ref.read(apiClientProvider);
  TokenStorage get _tokens => ref.read(tokenStorageProvider);

  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthState();
  }

  Future<void> _restore() async {
    final accessToken = await _tokens.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      state = const AuthState(initialized: true);
      return;
    }
    try {
      final user = await _api.me();
      state = AuthState(user: user, initialized: true);
    } catch (_) {
      await _tokens.clear();
      state = const AuthState(initialized: true);
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final auth = await _api.signIn(email, password);
      await _tokens.saveTokens(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
        userId: auth.user.id,
      );
      state = AuthState(user: auth.user, initialized: true);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(loading: false, error: error.message);
      return false;
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final auth = await _api.signUp(name: name, email: email, password: password);
      await _tokens.saveTokens(
        accessToken: auth.accessToken,
        refreshToken: auth.refreshToken,
        userId: auth.user.id,
      );
      state = AuthState(user: auth.user, initialized: true);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(loading: false, error: error.message);
      return false;
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      final user = state.user;
      if (user != null) {
        state = AuthState(
          user: User(
            id: user.id,
            displayName: user.displayName,
            email: user.email,
            role: user.role,
            mustChangePassword: false,
          ),
          initialized: true,
        );
      } else {
        state = state.copyWith(loading: false);
      }
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(loading: false, error: error.message);
      return false;
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
      return false;
    }
  }

  Future<void> refreshUser() async {
    try {
      final user = await _api.me();
      state = AuthState(user: user, initialized: true);
    } catch (_) {
      // Keep the current session on transient errors.
    }
  }

  Future<void> logout() async {
    await _tokens.clear();
    state = const AuthState(initialized: true);
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }
}
