import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/pagination/paged.dart';
import '../../../core/utils/firestore_utils.dart';
import '../../../core/utils/validators.dart';
import '../domain/entities/question.dart';
import '../domain/repositories/qa_repository.dart';

abstract final class QaModel {
  static const questions = 'questions';
  static const answers = 'answers';
  static const officialAnswerId = 'official';

  static Question questionFromMap(String id, Map<String, dynamic> d) =>
      Question(
        id: id,
        ownerUid: readString(d, 'ownerUid'),
        title: readString(d, 'title'),
        body: readString(d, 'body'),
        category: readString(d, 'category'),
        scriptureReference: readString(d, 'scriptureReference'),
        visibility: QuestionVisibility.fromWire(d['visibility']),
        status: QuestionStatus.fromWire(d['status']),
        answeredAt: readDate(d['answeredAt']),
        answeredByName: readOptionalString(d, 'answeredByName'),
        createdAt: readDate(d['createdAt']),
        updatedAt: readDate(d['updatedAt']),
      );

  static OfficialAnswer answerFromMap(
    String questionId,
    Map<String, dynamic> d,
  ) => OfficialAnswer(
    questionId: questionId,
    adminUid: readString(d, 'adminUid'),
    adminName: readString(d, 'adminName'),
    body: readString(d, 'body'),
    status: AnswerStatus.fromWire(d['status']),
    publishedAt: readDate(d['publishedAt']),
    updatedAt: readDate(d['updatedAt']),
  );

  static DocumentReference<Map<String, dynamic>> answerRef(
    FirebaseFirestore db,
    String qid,
  ) => db
      .collection(questions)
      .doc(qid)
      .collection(answers)
      .doc(officialAnswerId);
}

class FirestoreQaRepository implements QaRepository {
  FirestoreQaRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection(QaModel.questions);

  @override
  Future<String> ask(NewQuestion q, String ownerUid) => guard(() async {
    if (q.title.trim().isEmpty) {
      throw const AppException.validation('Add a short question title.');
    }
    if (q.body.trim().length > Limits.questionBodyMax) {
      throw const AppException.validation('Your question is too long.');
    }
    final ref = _col.doc();
    await ref.set({
      'ownerUid': ownerUid,
      'title': q.title.trim(),
      'body': q.body.trim(),
      'category': q.category,
      'scriptureReference': q.scriptureReference.trim(),
      'visibility': q.visibility.wire,
      'status': QuestionStatus.open.wire,
      'answeredAt': null,
      'answeredByName': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  });

  @override
  Stream<List<Question>> watchMine(String ownerUid, {int limit = 50}) => _col
      .where('ownerUid', isEqualTo: ownerUid)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => QaModel.questionFromMap(d.id, d.data())).toList(),
      );

  @override
  Stream<Question?> watchQuestion(String id) => _col
      .doc(id)
      .snapshots()
      .map(
        (s) => s.exists && s.data() != null
            ? QaModel.questionFromMap(s.id, s.data()!)
            : null,
      );

  @override
  Stream<OfficialAnswer?> watchOfficialAnswer(
    String questionId,
  ) => QaModel.answerRef(_db, questionId)
      .snapshots()
      .map<OfficialAnswer?>((s) {
        if (!s.exists || s.data() == null) return null;
        final a = QaModel.answerFromMap(questionId, s.data()!);
        return a.isPublished ? a : null;
      })
      .transform(
        StreamTransformer.fromHandlers(
          handleError: (e, st, sink) {
            // Non-admins are denied draft answers by rules: "no answer yet".
            if (e is FirebaseException && e.code == 'permission-denied') {
              sink.add(null);
            } else {
              sink.addError(AppException.from(e, st), st);
            }
          },
        ),
      );

  Query<Map<String, dynamic>> get _community => _col
      .where('visibility', isEqualTo: QuestionVisibility.public.wire)
      .where('status', isEqualTo: QuestionStatus.answered.wire)
      .orderBy('answeredAt', descending: true);

  @override
  Future<PageResult<Question>> fetchCommunity({
    Object? cursor,
    int limit = 20,
  }) => guard(() async {
    var q = _community;
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    q = q.limit(limit);
    final snap = await q.get();
    return PageResult(
      snap.docs.map((d) => QaModel.questionFromMap(d.id, d.data())).toList(),
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  });

  @override
  Stream<List<Question>> watchRecentlyAnswered({int limit = 1}) => _community
      .limit(limit)
      .snapshots()
      .map(
        (s) =>
            s.docs.map((d) => QaModel.questionFromMap(d.id, d.data())).toList(),
      );

  @override
  Future<void> closeMine(String questionId) => guard(
    () => _col.doc(questionId).update({
      'status': QuestionStatus.closed.wire,
      'updatedAt': FieldValue.serverTimestamp(),
    }),
  );
}
