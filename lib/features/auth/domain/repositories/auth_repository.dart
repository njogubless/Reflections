import '../entities/app_user.dart';

abstract class AuthRepository {
  /// Emits the signed-in user (with role from ID-token claims) or null.
  /// Re-emits whenever the ID token refreshes, so claim changes propagate.
  Stream<AppUser?> watchUser();

  Future<void> signIn({required String email, required String password});

  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  });

  Future<void> sendPasswordReset(String email);

  Future<void> sendEmailVerification();

  /// Forces an ID-token refresh so newly assigned roles take effect.
  Future<void> refreshClaims();

  Future<void> updateDisplayName(String displayName);

  Future<void> signOut();
}
