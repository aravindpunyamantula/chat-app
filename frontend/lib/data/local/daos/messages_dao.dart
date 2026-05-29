import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/messages_table.dart';

part 'messages_dao.g.dart';

@DriftAccessor(tables: [MessagesTable])
class MessagesDao extends DatabaseAccessor<AppDatabase>
    with _$MessagesDaoMixin {
  MessagesDao(super.db);

  Stream<List<MessagesTableData>> watchMessages(
    String conversationId, {
    int limit = 60,
  }) {
    return (select(messagesTable)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)])
          ..limit(limit))
        .watch();
  }

  Future<List<MessagesTableData>> getMessagesBefore(
    String conversationId,
    DateTime before, {
    int limit = 20,
  }) {
    return (select(messagesTable)
          ..where(
            (m) =>
                m.conversationId.equals(conversationId) &
                m.createdAt.isSmallerThanValue(before),
          )
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<List<MessagesTableData>> getPendingMessages() {
    return (select(messagesTable)
          ..where((m) => m.status.equals('pending'))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get();
  }

  Future<void> upsertMessage(MessagesTableCompanion entry) {
    return into(messagesTable).insertOnConflictUpdate(entry);
  }

  Future<void> upsertMessages(List<MessagesTableCompanion> entries) async {
    if (entries.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(messagesTable, entries));
  }

  Future<void> updateStatus(String id, String status) {
    return (update(messagesTable)..where((m) => m.id.equals(id))).write(
      MessagesTableCompanion(status: Value(status)),
    );
  }

  Future<void> replaceTempId({
    required String tempId,
    required String serverId,
    required String status,
  }) async {
    final existing = await (select(
      messagesTable,
    )..where((m) => m.id.equals(tempId))).getSingleOrNull();
    if (existing == null) return;

    await transaction(() async {
      await (delete(messagesTable)..where((m) => m.id.equals(tempId))).go();

      await into(messagesTable).insertOnConflictUpdate(
        existing
            .toCompanion(true)
            .copyWith(id: Value(serverId), status: Value(status)),
      );
    });
  }

  Future<void> deleteByConversation(String conversationId) {
    return (delete(
      messagesTable,
    )..where((m) => m.conversationId.equals(conversationId))).go();
  }
}
