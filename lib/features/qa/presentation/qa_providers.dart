import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/pagination/paged.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/qa_data.dart';
import '../domain/entities/question.dart';
import '../domain/repositories/qa_repository.dart';

final qaRepositoryProvider = Provider<QaRepository>(
  (ref) => FirestoreQaRepository(ref.watch(firestoreProvider)),
);

final myQuestionsProvider = StreamProvider.autoDispose<List<Question>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.watch(qaRepositoryProvider).watchMine(user.uid);
});

final questionProvider = StreamProvider.autoDispose.family<Question?, String>(
  (ref, id) => ref.watch(qaRepositoryProvider).watchQuestion(id),
);

/// Subscribes to the answer only once the question is `answered` (rules keep
/// drafts admin-only), and resubscribes whenever the question status changes.
final officialAnswerProvider = StreamProvider.autoDispose
    .family<OfficialAnswer?, String>((ref, id) {
      final status = ref.watch(
        questionProvider(id).select((q) => q.value?.status),
      );
      if (status != QuestionStatus.answered) return Stream.value(null);
      return ref.watch(qaRepositoryProvider).watchOfficialAnswer(id);
    });

final recentlyAnsweredProvider = StreamProvider.autoDispose<List<Question>>(
  (ref) => ref.watch(qaRepositoryProvider).watchRecentlyAnswered(),
);

class CommunityQuestions extends PagedNotifier<Question> {
  @override
  Future<PageResult<Question>> fetchPage(Object? cursor, int limit) => ref
      .read(qaRepositoryProvider)
      .fetchCommunity(cursor: cursor, limit: limit);
}

final communityQuestionsProvider =
    NotifierProvider.autoDispose<CommunityQuestions, PagedState<Question>>(
      CommunityQuestions.new,
    );

/// Ask / close actions with duplicate-tap protection.
class QuestionActions extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> ask(NewQuestion q) async {
    if (state.isLoading) return null;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = AsyncError(const AppException.permission(), StackTrace.current);
      return null;
    }
    state = const AsyncLoading();
    try {
      final id = await ref.read(qaRepositoryProvider).ask(q, user.uid);
      if (ref.mounted) state = const AsyncData(null);
      return id;
    } catch (e, s) {
      if (ref.mounted) state = AsyncError(AppException.from(e, s), s);
      return null;
    }
  }

  Future<bool> close(String id) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await ref.read(qaRepositoryProvider).closeMine(id);
      if (ref.mounted) state = const AsyncData(null);
      return true;
    } catch (e, s) {
      if (ref.mounted) state = AsyncError(AppException.from(e, s), s);
      return false;
    }
  }
}

final questionActionsProvider =
    NotifierProvider.autoDispose<QuestionActions, AsyncValue<void>>(
      QuestionActions.new,
    );
