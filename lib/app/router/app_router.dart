import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_article_pages.dart';
import '../../features/admin/presentation/pages/admin_book_pages.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/admin_qa_pages.dart';
import '../../features/admin/presentation/pages/admin_sermon_pages.dart';
import '../../features/admin/presentation/pages/review_pages.dart';
import '../../features/articles/presentation/article_pages.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/auth/presentation/pages/auth_pages.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/books/presentation/book_pages.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/home/presentation/pages/read_page.dart';
import '../../features/notifications/presentation/notification_pages.dart';
import '../../features/profile/presentation/profile_pages.dart';
import '../../features/qa/presentation/qa_pages.dart';
import '../../features/recording/presentation/pages/my_recordings_page.dart';
import '../../features/recording/presentation/pages/recording_detail_page.dart';
import '../../features/recording/presentation/pages/recording_studio_page.dart';
import '../../features/recording/presentation/pages/submit_recording_page.dart';
import '../../features/sermons/presentation/pages/sermon_library_page.dart';
import '../../features/sermons/presentation/pages/sermon_player_page.dart';
import 'app_shell.dart';
import 'auth_redirect.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

AuthSnapshot authSnapshotOf(AsyncValue<AppUser?> auth) {
  if (auth.hasValue) {
    final user = auth.value;
    return user == null ? const SignedOut() : SignedIn(user);
  }
  if (auth.hasError) return const SignedOut();
  return const AuthLoading();
}

/// Re-runs redirects when auth or role changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    ref.listen<AsyncValue<AppUser?>>(authStateProvider, (prev, next) {
      final a = prev == null ? null : authSnapshotOf(prev);
      final b = authSnapshotOf(next);
      final changed = switch ((a, b)) {
        (SignedIn(user: final x), SignedIn(user: final y)) =>
          x.uid != y.uid || x.role != y.role,
        _ => a.runtimeType != b.runtimeType,
      };
      if (changed) notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh(ref);
  ref.onDispose(refresh.dispose);

  GoRoute full(String path, Widget Function(GoRouterState s) build) => GoRoute(
    path: path,
    parentNavigatorKey: _rootKey,
    builder: (_, s) => build(s),
  );

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) =>
        resolveRedirect(authSnapshotOf(ref.read(authStateProvider)), state.uri),
    errorBuilder: (_, _) =>
        const Scaffold(body: Center(child: Text('Page not found'))),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInPage()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(path: Routes.forbidden, builder: (_, _) => const ForbiddenPage()),

      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.sermons,
                builder: (_, _) => const SermonLibraryPage(),
                routes: [
                  full(
                    ':id',
                    (s) => SermonPlayerPage(sermonId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.read, builder: (_, _) => const ReadPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.questions,
                builder: (_, _) => const QuestionsPage(),
                routes: [
                  full('ask', (_) => const AskQuestionPage()),
                  full('mine', (_) => const MyQuestionsPage()),
                  full(
                    ':id',
                    (s) =>
                        QuestionDetailPage(questionId: s.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfilePage(),
                routes: [full('edit', (_) => const EditProfilePage())],
              ),
            ],
          ),
        ],
      ),

      // Recording studio (user submissions).
      full(
        Routes.studio,
        (s) => RecordingStudioPage(
          resubmissionOf: s.uri.queryParameters['resubmit'],
        ),
      ),
      full(
        '/studio/submit/:draftId',
        (s) => SubmitRecordingPage(draftId: s.pathParameters['draftId']!),
      ),
      full(Routes.myRecordings, (_) => const MyRecordingsPage()),
      full(
        '/recordings/:id',
        (s) => RecordingDetailPage(recordingId: s.pathParameters['id']!),
      ),

      // Reading.
      full(
        '/books/:id',
        (s) => BookDetailPage(bookId: s.pathParameters['id']!),
      ),
      full(
        '/books/:id/read',
        (s) => BookReaderPage(bookId: s.pathParameters['id']!),
      ),
      full(
        '/articles/:id',
        (s) => ArticleReaderPage(articleId: s.pathParameters['id']!),
      ),

      full(Routes.notifications, (_) => const NotificationsPage()),

      // Admin workspace — guarded by resolveRedirect and AdminGate.
      GoRoute(
        path: Routes.admin,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const AdminDashboardPage(),
        routes: [
          GoRoute(
            path: 'sermons',
            builder: (_, _) => const AdminSermonsPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const AdminSermonEditorPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    AdminSermonEditorPage(sermonId: s.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: 'reviews',
            builder: (_, _) => const ReviewQueuePage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    ReviewDetailPage(recordingId: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: 'books',
            builder: (_, _) => const AdminBooksPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const AdminBookEditorPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    AdminBookEditorPage(bookId: s.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: 'articles',
            builder: (_, _) => const AdminArticlesPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (_, _) => const AdminArticleEditorPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    AdminArticleEditorPage(articleId: s.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: 'questions',
            builder: (_, _) => const QuestionInboxPage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) =>
                    AnswerEditorPage(questionId: s.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
