import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/entities/app_user.dart';
import '../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _profile(String uid) =>
      _db.collection('users').doc(uid);

  @override
  Stream<AppUser?> watchUser() => _auth.idTokenChanges().asyncMap((user) async {
    if (user == null) return null;
    final token = await user.getIdTokenResult();
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName ?? '',
      emailVerified: user.emailVerified,
      photoUrl: user.photoURL,
      role: UserRole.fromClaim(token.claims?['role']),
    );
  });

  @override
  Future<void> signIn({required String email, required String password}) =>
      guard(() async {
        final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await _ensureProfile(cred.user!);
      });

  @override
  Future<void> register({
    required String displayName,
    required String email,
    required String password,
  }) => guard(() async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(displayName.trim());
    await _ensureProfile(user, displayName: displayName.trim());
    await user.sendEmailVerification();
    // Re-emit with the display name applied.
    await user.reload();
    await user.getIdToken(true);
  });

  /// Creates the profile document if missing. Never writes `role` — rules
  /// reject it; roles are assigned server-side.
  Future<void> _ensureProfile(User user, {String? displayName}) async {
    final ref = _profile(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'displayName': displayName ?? user.displayName ?? '',
      'email': user.email,
      'photoUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> sendEmailVerification() => guard(() async {
    await _auth.currentUser?.sendEmailVerification();
  });

  @override
  Future<void> refreshClaims() => guard(() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reload();
    await user.getIdToken(true);
  });

  @override
  Future<void> updateDisplayName(String displayName) => guard(() async {
    final user = _auth.currentUser;
    if (user == null) throw const AppException.permission();
    await user.updateDisplayName(displayName.trim());
    await _profile(user.uid).set({
      'displayName': displayName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await user.getIdToken(true);
  });

  @override
  Future<void> signOut() => guard(_auth.signOut);
}
