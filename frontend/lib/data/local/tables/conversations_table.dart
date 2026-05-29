import 'package:drift/drift.dart';

class ConversationsTable extends Table {
  TextColumn get id => text()();

  TextColumn get groupName => text().withDefault(const Constant(''))();
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();

  TextColumn get lastMessageId => text().nullable()();
  TextColumn get lastMessageContent => text().nullable()();
  TextColumn get lastMessageStatus => text().nullable()();
  TextColumn get lastMessageSenderId => text().nullable()();

  TextColumn get participantsJson => text().withDefault(const Constant('[]'))();

  DateTimeColumn get updatedAt => dateTime().withDefault(
    Constant(DateTime.fromMillisecondsSinceEpoch(0)),
  )();

  @override
  Set<Column> get primaryKey => {id};
}
