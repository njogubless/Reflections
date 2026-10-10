import '../../../../core/pagination/paged.dart';
import '../entities/question.dart';

abstract class QaRepository {
  /// Returns the new question's ID.
  Future<String> ask(NewQuestion question, String ownerUid);

  Stream<List<Question>> watchMine(String ownerUid, {int limit = 50});

  Stream<Question?> watchQuestion(String id);

  /// Emits null until an official answer is published (drafts are hidden).
  Stream<OfficialAnswer?> watchOfficialAnswer(String questionId);

  /// Answered questions the askers chose to share (no identities exposed).
  Future<PageResult<Question>> fetchCommunity({Object? cursor, int limit = 20});

  Stream<List<Question>> watchRecentlyAnswered({int limit = 1});

  Future<void> closeMine(String questionId);
}
