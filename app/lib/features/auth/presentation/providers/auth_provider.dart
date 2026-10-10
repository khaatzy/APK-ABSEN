import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';
import '../../domain/app_user.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
  return AuthController(ref.watch(authRepositoryProvider));
});

class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  final AuthRepository _authRepository;

  AuthController(this._authRepository) : super(const AsyncValue.data(null)) {
    _checkAuthState();
  }

  void _checkAuthState() {
    _authRepository.authStateChanges().listen((user) async {
      if (user == null) {
        state = const AsyncValue.data(null);
      } else {
        state = const AsyncValue.loading();
        try {
          final userData = await _authRepository.getUserData(user.uid);
          state = AsyncValue.data(userData);
        } catch (e, st) {
          state = AsyncValue.error(e, st);
        }
      }
    });
  }

  Future<void> loginSiswa(String nisn, String nik) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.loginSiswa(nisn, nik);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> loginUmum(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _authRepository.loginUmum(email, password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
  }
}
