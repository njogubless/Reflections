/// Roles come exclusively from Firebase Auth custom claims (server-assigned).
enum UserRole {
  user,
  minister,
  admin;

  static UserRole fromClaim(Object? claim) => switch (claim) {
    'admin' => UserRole.admin,
    'minister' => UserRole.minister,
    _ => UserRole.user,
  };

  String get label => switch (this) {
    UserRole.user => 'Member',
    UserRole.minister => 'Minister',
    UserRole.admin => 'Administrator',
  };
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.emailVerified = false,
    this.photoUrl,
  });

  final String uid;
  final String? email;
  final String displayName;
  final UserRole role;
  final bool emailVerified;
  final String? photoUrl;

  bool get isAdmin => role == UserRole.admin;
  bool get isMinister => role == UserRole.minister;

  String get firstName {
    final n = displayName.trim();
    if (n.isEmpty) return 'Friend';
    return n.split(RegExp(r'\s+')).first;
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.role == role &&
      other.emailVerified == emailVerified &&
      other.photoUrl == photoUrl;

  @override
  int get hashCode =>
      Object.hash(uid, email, displayName, role, emailVerified, photoUrl);
}

/// Client-side mirror of the recording eligibility policy. The server rule
/// `canSubmitRecordings()` in firestore.rules is authoritative.
abstract final class RecordingPolicy {
  static bool canRecord(AppUser? user) => user != null;
}
