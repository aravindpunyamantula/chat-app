import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/conversations_table.dart';

part 'conversations_dao.g.dart';

@DriftAccessor(tables: [ConversationsTable])
class ConversationsDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationsDaoMixin {
  ConversationsDao(super.db);

  Stream<List<ConversationsTableData>> watchAll() {
    return (select(
      conversationsTable,
    )..orderBy([(c) => OrderingTerm.desc(c.updatedAt)])).watch();
  }

  Future<ConversationsTableData?> getById(String id) {
    return (select(
      conversationsTable,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertConversation(ConversationsTableCompanion entry) {
    return into(conversationsTable).insertOnConflictUpdate(entry);
  }

  Future<void> upsertConversations(
    List<ConversationsTableCompanion> entries,
  ) async {
    await batch(
      (b) => b.insertAllOnConflictUpdate(conversationsTable, entries),
    );
  }

  Future<void> updateLastMessage({
    required String conversationId,
    required String messageId,
    required String content,
    required String status,
    required String senderId,
  }) {
    return (update(
      conversationsTable,
    )..where((c) => c.id.equals(conversationId))).write(
      ConversationsTableCompanion(
        lastMessageId: Value(messageId),
        lastMessageContent: Value(content),
        lastMessageStatus: Value(status),
        lastMessageSenderId: Value(senderId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> updateLastMessageStatus(String conversationId, String status) {
    return (update(
      conversationsTable,
    )..where((c) => c.id.equals(conversationId))).write(
      ConversationsTableCompanion(
        lastMessageStatus: Value(status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
