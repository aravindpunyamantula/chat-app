import 'dart:convert';
import 'package:drift/drift.dart';
import '../local/app_database.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class LocalChatRepository {
  final AppDatabase _db;

  LocalChatRepository(this._db);

  Stream<List<ConversationModel>> watchConversations() {
    return _db.conversationsDao.watchAll().map(
      (rows) => rows.map(_rowToConversation).toList(),
    );
  }

  Stream<List<MessageModel>> watchMessages(String conversationId) {
    return _db.messagesDao
        .watchMessages(conversationId)
        .map((rows) => rows.map(_rowToMessage).toList());
  }

  Stream<List<UserModel>> watchUsers() {
    return _db.usersDao.watchAll().map((rows) => rows.map(_rowToUser).toList());
  }

  Future<void> upsertConversations(List<ConversationModel> conversations) {
    return _db.conversationsDao.upsertConversations(
      conversations.map(_conversationToCompanion).toList(),
    );
  }

  Future<void> upsertMessages(
    List<MessageModel> messages, {
    required bool isMine,
  }) {
    return _db.messagesDao.upsertMessages(
      messages.map((m) => _messageToCompanion(m, isMine: isMine)).toList(),
    );
  }

  Future<void> saveMessageLocally(
    MessageModel message, {
    required bool isMine,
  }) {
    return _db.messagesDao.upsertMessage(
      _messageToCompanion(message, isMine: isMine),
    );
  }

  Future<void> updateMessageStatus(String id, String status) {
    return _db.messagesDao.updateStatus(id, status);
  }

  Future<void> replaceTempId({
    required String tempId,
    required String serverId,
    required String status,
  }) {
    return _db.messagesDao.replaceTempId(
      tempId: tempId,
      serverId: serverId,
      status: status,
    );
  }

  Future<void> upsertUsers(List<UserModel> users) {
    return _db.usersDao.upsertUsers(users.map(_userToCompanion).toList());
  }

  Future<void> updateUserOnlineStatus({
    required String userId,
    required bool isOnline,
    DateTime? lastSeen,
  }) {
    return _db.usersDao.updateOnlineStatus(
      userId: userId,
      isOnline: isOnline,
      lastSeen: lastSeen,
    );
  }

  Future<void> updateConversationLastMessage({
    required String conversationId,
    required String messageId,
    required String content,
    required String status,
    required String senderId,
  }) {
    return _db.conversationsDao.updateLastMessage(
      conversationId: conversationId,
      messageId: messageId,
      content: content,
      status: status,
      senderId: senderId,
    );
  }

  Future<void> updateConversationLastMessageStatus(
    String conversationId,
    String status,
  ) {
    return _db.conversationsDao.updateLastMessageStatus(
      conversationId,
      status,
    );
  }

  Future<List<MessageModel>> getPendingMessages() async {
    final rows = await _db.messagesDao.getPendingMessages();
    return rows.map(_rowToMessage).toList();
  }

  Future<List<MessageModel>> getMessagesBefore(
    String conversationId,
    DateTime before, {
    int limit = 20,
  }) async {
    final rows = await _db.messagesDao.getMessagesBefore(
      conversationId,
      before,
      limit: limit,
    );
    return rows.map(_rowToMessage).toList();
  }

  ConversationModel _rowToConversation(ConversationsTableData row) {
    List<UserModel> participants = [];
    try {
      final decoded = jsonDecode(row.participantsJson) as List<dynamic>;
      participants = decoded
          .map((p) => UserModel.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList();
    } catch (_) {}

    MessageModel? lastMessage;
    if (row.lastMessageId != null && row.lastMessageContent != null) {
      final senderModel = participants.firstWhere(
        (p) => p.id == row.lastMessageSenderId,
        orElse: () => _unknownUser(row.lastMessageSenderId ?? ''),
      );
      lastMessage = MessageModel(
        id: row.lastMessageId!,
        tempId: null,
        conversationId: row.id,
        sender: senderModel,
        content: row.lastMessageContent!,
        messageType: 'text',
        fileUrl: '',
        createdAt: row.updatedAt,
        status: row.lastMessageStatus ?? 'sent',
      );
    }

    return ConversationModel(
      id: row.id,
      participants: participants,
      isGroup: row.isGroup,
      groupName: row.groupName,
      lastMessage: lastMessage,
      updatedAt: row.updatedAt,
    );
  }

  MessageModel _rowToMessage(MessagesTableData row) {
    return MessageModel(
      id: row.id,
      tempId: row.id.startsWith('temp_') ? row.id : null,
      conversationId: row.conversationId,
      sender: UserModel(
        id: row.senderId,
        name: row.senderName,
        email: row.senderEmail,
        profileImage: row.senderProfileImage,
        isOnline: row.senderIsOnline,
        lastSeen: DateTime.now(),
      ),
      content: row.content,
      messageType: row.messageType,
      fileUrl: row.fileUrl,
      createdAt: row.createdAt,
      status: row.status,
    );
  }

  UserModel _rowToUser(UsersTableData row) {
    return UserModel(
      id: row.id,
      name: row.name,
      email: row.email,
      profileImage: row.profileImage,
      isOnline: row.isOnline,
      lastSeen: row.lastSeen,
    );
  }

  ConversationsTableCompanion _conversationToCompanion(ConversationModel c) {
    final participantsJson = jsonEncode(
      c.participants.map((p) => p.toJson()).toList(),
    );
    return ConversationsTableCompanion.insert(
      id: c.id,
      groupName: Value(c.groupName),
      isGroup: Value(c.isGroup),
      lastMessageId: Value(c.lastMessage?.id),
      lastMessageContent: Value(c.lastMessage?.content),
      lastMessageStatus: Value(c.lastMessage?.status),
      lastMessageSenderId: Value(c.lastMessage?.sender.id),
      participantsJson: Value(participantsJson),
      updatedAt: Value(DateTime.now()),
    );
  }

  MessagesTableCompanion _messageToCompanion(
    MessageModel m, {
    required bool isMine,
  }) {
    return MessagesTableCompanion.insert(
      id: m.id,
      conversationId: m.conversationId,
      senderId: m.sender.id,
      senderName: Value(m.sender.name),
      senderEmail: Value(m.sender.email),
      senderProfileImage: Value(m.sender.profileImage),
      senderIsOnline: Value(m.sender.isOnline),
      content: m.content,
      messageType: Value(m.messageType),
      fileUrl: Value(m.fileUrl),
      status: Value(m.status),
      createdAt: Value(m.createdAt),
      isMine: Value(isMine),
    );
  }

  UsersTableCompanion _userToCompanion(UserModel u) {
    return UsersTableCompanion.insert(
      id: u.id,
      name: u.name,
      email: u.email,
      profileImage: Value(u.profileImage),
      isOnline: Value(u.isOnline),
      lastSeen: Value(u.lastSeen),
    );
  }

  UserModel _unknownUser(String id) {
    return UserModel(
      id: id,
      name: 'Unknown',
      email: '',
      profileImage: '',
      isOnline: false,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Future<void> clearAll() async {
    await _db.transaction(() async {
      for (final table in _db.allTables) {
        await _db.delete(table).go();
      }
    });
  }
}
