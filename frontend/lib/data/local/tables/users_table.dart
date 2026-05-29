import 'package:drift/drift.dart';

class UsersTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get email => text()();
  TextColumn get profileImage => text().withDefault(const Constant(''))();
  BoolColumn get isOnline => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSeen => dateTime().withDefault(
    Constant(DateTime.fromMillisecondsSinceEpoch(0)),
  )();

  @override
  Set<Column> get primaryKey => {id};
}
