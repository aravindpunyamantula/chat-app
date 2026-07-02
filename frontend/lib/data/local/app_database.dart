import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables/conversations_table.dart';
import 'tables/messages_table.dart';
import 'tables/users_table.dart';
import 'daos/conversations_dao.dart';
import 'daos/messages_dao.dart';
import 'daos/users_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [ConversationsTable, MessagesTable, UsersTable],
  daos: [ConversationsDao, MessagesDao, UsersDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await customStatement(
          'ALTER TABLE messages_table ADD COLUMN file_url TEXT NOT NULL DEFAULT ""',
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA journal_mode=WAL');
      await customStatement('PRAGMA foreign_keys=ON');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'chat_app_db',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
        onResult: (result) {
          if (result.missingFeatures.isNotEmpty) {
            print('Using ${result.chosenImplementation} due to missing browser features: ${result.missingFeatures}');
          }
        },
      ),
    );
  }
}
