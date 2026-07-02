import 'package:drift/drift.dart';

class MessagesTable extends Table {
  TextColumn get id => text()();

  TextColumn get conversationId => text()();

  TextColumn get senderId => text()();
  TextColumn get senderName => text().withDefault(const Constant(''))();
  TextColumn get senderEmail => text().withDefault(const Constant(''))();
  TextColumn get senderProfileImage => text().withDefault(const Constant(''))();
  BoolColumn get senderIsOnline =>
      boolean().withDefault(const Constant(false))();

  TextColumn get content => text()();
  TextColumn get messageType => text().withDefault(const Constant('text'))();
  TextColumn get fileUrl => text().withDefault(const Constant(''))();

  TextColumn get status => text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(Constant(DateTime.now()))();

  BoolColumn get isMine => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
