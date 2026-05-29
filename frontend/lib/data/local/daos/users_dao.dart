import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/users_table.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: [UsersTable])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Stream<List<UsersTableData>> watchAll() {
    return (select(
      usersTable,
    )..orderBy([(u) => OrderingTerm.asc(u.name)])).watch();
  }

  Future<UsersTableData?> getById(String id) {
    return (select(
      usersTable,
    )..where((u) => u.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertUser(UsersTableCompanion entry) {
    return into(usersTable).insertOnConflictUpdate(entry);
  }

  Future<void> upsertUsers(List<UsersTableCompanion> entries) async {
    if (entries.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(usersTable, entries));
  }

  Future<void> updateOnlineStatus({
    required String userId,
    required bool isOnline,
    DateTime? lastSeen,
  }) {
    return (update(usersTable)..where((u) => u.id.equals(userId))).write(
      UsersTableCompanion(
        isOnline: Value(isOnline),
        lastSeen: lastSeen != null ? Value(lastSeen) : const Value.absent(),
      ),
    );
  }
}
