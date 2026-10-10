import '../../features/auth/domain/entities/app_user.dart';
import 'routes.dart';

/// Snapshot of authentication for routing decisions.
sealed class AuthSnapshot {
  const AuthSnapshot();
}

class AuthLoading extends AuthSnapshot {
  const AuthLoading();
}

class SignedOut extends AuthSnapshot {
  const SignedOut();
}

class SignedIn extends AuthSnapshot {
  const SignedIn(this.user);
  final AppUser user;
}

/// Pure redirect policy (unit tested). Returns the location to redirect to,
/// or null to allow navigation.
///
/// - While auth state is unresolved, hold on the splash route (no loops:
///   splash itself is never redirected while loading).
/// - Signed-out users may only reach public auth routes; the intended
///   destination is preserved in `from`.
/// - Signed-in users leave auth routes for `from` (if safe) or home.
/// - `/admin/**` requires the admin role from ID-token claims.
///
/// This is a UX guard only; Firestore/Storage rules are the security boundary.
String? resolveRedirect(AuthSnapshot auth, Uri uri) {
  final path = uri.path;
  final isPublic = Routes.publicPaths.contains(path);
  final isSplash = path == Routes.splash;

  switch (auth) {
    case AuthLoading():
      return isSplash ? null : _withFrom(Routes.splash, uri);
    case SignedOut():
      if (isPublic) return null;
      final from = isSplash ? uri.queryParameters['from'] : uri.toString();
      return _withFromValue(Routes.signIn, from);
    case SignedIn(:final user):
      if (isPublic || isSplash) {
        final from = uri.queryParameters['from'];
        if (from != null && _isSafeInternal(from) && !_isAuthPath(from)) {
          return _canAccess(user, Uri.parse(from).path)
              ? from
              : Routes.forbidden;
        }
        return Routes.home;
      }
      if (path == '/') return Routes.home;
      if (!_canAccess(user, path)) return Routes.forbidden;
      return null;
  }
}

bool isAdminPath(String path) =>
    path == Routes.admin || path.startsWith('${Routes.admin}/');

bool _canAccess(AppUser user, String path) =>
    !isAdminPath(path) || user.isAdmin;

bool _isAuthPath(String location) {
  final p = Uri.parse(location).path;
  return Routes.publicPaths.contains(p) || p == Routes.splash;
}

/// Only allow relative in-app paths as redirect targets.
bool _isSafeInternal(String location) =>
    location.startsWith('/') && !location.startsWith('//');

String _withFrom(String target, Uri uri) {
  final from = uri.path == '/' ? null : uri.toString();
  return _withFromValue(target, from);
}

String _withFromValue(String target, String? from) {
  if (from == null ||
      from.isEmpty ||
      !_isSafeInternal(from) ||
      _isAuthPath(from)) {
    return target;
  }
  return Uri(path: target, queryParameters: {'from': from}).toString();
}
