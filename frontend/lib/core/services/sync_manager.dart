import '../../data/repositories/local_chat_repository.dart';
import '../../data/repositories/remote_chat_repository.dart';
import '../../core/utils/logger.dart';

class SyncManager {
  final LocalChatRepository _local;
  final RemoteChatRepository _remote;

  bool _isSyncing = false;

  SyncManager({
    required LocalChatRepository local,
    required RemoteChatRepository remote,
  }) : _local = local,
       _remote = remote;

  Future<void> syncAll({required String currentUserId}) async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await Future.wait([
        _syncConversations(currentUserId: currentUserId),
        _syncUsers(),
      ]);
      AppLogger.info('SyncManager: full sync complete');
    } catch (e) {
      AppLogger.warn('SyncManager: syncAll error — $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> syncMessages(
    String conversationId, {
    required String currentUserId,
    int limit = 30,
  }) async {
    try {
      final page = await _remote.getMessages(conversationId, limit: limit);
      await _local.upsertMessages(
        page.messages,
        isMine: false, // We set isMine per message in the mapper below
      );

      for (final msg in page.messages) {
        final isMine = msg.sender.id == currentUserId;
        await _local.saveMessageLocally(msg, isMine: isMine);
      }
      AppLogger.info(
        'SyncManager: synced ${page.messages.length} messages for $conversationId',
      );
    } catch (e) {
      AppLogger.warn(
        'SyncManager: syncMessages error for $conversationId — $e',
      );
    }
  }

  Future<void> refreshConversations({required String currentUserId}) async {
    await _syncConversations(currentUserId: currentUserId).catchError(
      (e) => AppLogger.warn('SyncManager: refresh conversations error — $e'),
    );
  }

  Future<void> _syncConversations({required String currentUserId}) async {
    final remote = await _remote.getConversations();
    if (remote.isEmpty) return;
    await _local.upsertConversations(remote);
  }

  Future<void> _syncUsers() async {
    final remote = await _remote.getUsers();
    if (remote.isEmpty) return;
    await _local.upsertUsers(remote);
  }
}
