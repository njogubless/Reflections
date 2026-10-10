import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../providers/auth_providers.dart';

/// Explicit loading/error state for auth form submissions.
class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> _run(Future<void> Function() action) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action();
      if (!ref.mounted) return true;
      state = const AsyncData(null);
      return true;
    } catch (e, s) {
      if (!ref.mounted) return false;
      state = AsyncError(AppException.from(e, s), s);
      return false;
    }
  }

  Future<bool> signIn(String email, String password) => _run(
    () => ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password),
  );

  Future<bool> register(String name, String email, String password) => _run(
    () => ref
        .read(authRepositoryProvider)
        .register(displayName: name, email: email, password: password),
  );

  Future<bool> sendReset(String email) =>
      _run(() => ref.read(authRepositoryProvider).sendPasswordReset(email));

  void clearError() => state = const AsyncData(null);
}

final authControllerProvider =
    NotifierProvider.autoDispose<AuthController, AsyncValue<void>>(
      AuthController.new,
    );
