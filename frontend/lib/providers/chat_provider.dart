import 'dart:async';
import 'package:flutter/material.dart';
import '../core/network/socket_service.dart';
import '../core/services/sync_manager.dart';
import '../core/services/pending_queue_service.dart';
import '../core/utils/logger.dart';
import '../data/models/conversation_model.dart';
import '../data/models/message_model.dart';
import '../data/models/user_model.dart';
import '../data/repositories/local_chat_repository.dart';
import '../data/repositories/remote_chat_repository.dart';

class ChatProvider with ChangeNotifier {
  final LocalChatRepository _local;
  final RemoteChatRepository _remote;
  final SocketService _socket;
  final SyncManager _syncManager;
  final PendingQueueService _pendingQueue;

  List<ConversationModel> conversations = [];
  List<MessageModel> activeMessages = [];
  List<UserModel> users = [];

  String? activeConversationId;
  String? _currentUserId;
  String? typingUserName;

  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMoreMessages = false;

  SocketConnectionState get connectionState => _socket.connectionState.value;

  StreamSubscription<List<ConversationModel>>? _conversationsSub;
  StreamSubscription<List<MessageModel>>? _messagesSub;
  StreamSubscription<List<UserModel>>? _usersSub;

  ChatProvider({
    required LocalChatRepository local,
    required RemoteChatRepository remote,
    required SocketService socket,
    required SyncManager syncManager,
    required PendingQueueService pendingQueue,
  }) : _local = local,
       _remote = remote,
       _socket = socket,
       _syncManager = syncManager,
       _pendingQueue = pendingQueue {
    _initStreams();
    _registerSocketHooks();
    _socket.connectionState.addListener(_onSocketStateChanged);
  }

  void _initStreams() {
    _conversationsSub = _local.watchConversations().listen((data) {
      conversations = data;
      notifyListeners();
    });

    _usersSub = _local.watchUsers().listen((data) {
      users = data;
      notifyListeners();
    });
  }

  Future<void> clear() async {
    _currentUserId = null;
    activeConversationId = null;
    typingUserName = null;
    conversations.clear();
    activeMessages.clear();
    users.clear();
    await _local.clearAll();
    notifyListeners();
  }

  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    _pendingQueue.startMonitoring();

    _syncManager
        .syncAll(currentUserId: userId)
        .catchError((e) => AppLogger.warn('ChatProvider: syncAll error — $e'));
  }

  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
  }

  Future<void> selectConversation(String conversationId) async {
    activeConversationId = conversationId;
    typingUserName = null;

    await _messagesSub?.cancel();
    _messagesSub = _local.watchMessages(conversationId).listen((data) {
      activeMessages = data;
      notifyListeners();
    });

    _socket.joinConversation(conversationId);
    _socket.markAsRead(conversationId);
    await _local.updateConversationLastMessageStatus(conversationId, 'read');

    _syncManager
        .syncMessages(conversationId, currentUserId: _currentUserId ?? '')
        .catchError(
          (e) => AppLogger.warn('ChatProvider: syncMessages error — $e'),
        );

    notifyListeners();
  }

  void deselectConversation() {
    if (activeConversationId != null) {
      _socket.leaveConversation(activeConversationId!);
    }
    activeConversationId = null;
    typingUserName = null;
    _messagesSub?.cancel();
    _messagesSub = null;
    activeMessages = [];
    notifyListeners();
  }

  Future<void> sendRealtimeMessage(String content) async {
    if (activeConversationId == null || _currentUserId == null) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();

    final senderModel = _buildCurrentUserModel();

    final optimisticMessage = MessageModel(
      id: tempId,
      tempId: tempId,
      conversationId: activeConversationId!,
      sender: senderModel,
      content: content,
      messageType: 'text',
      fileUrl: '',
      createdAt: now,
      status: 'pending',
    );

    await _local.saveMessageLocally(optimisticMessage, isMine: true);

    await _local.updateConversationLastMessage(
      conversationId: activeConversationId!,
      messageId: tempId,
      content: content,
      status: 'pending',
      senderId: _currentUserId!,
    );

    _socket.sendMessage(
      {
        'conversationId': activeConversationId,
        'content': content,
        'tempId': tempId,
        'messageType': 'text',
      },
      ack: (dynamic response) async {
        if (response == null) return;
        final data = Map<String, dynamic>.from(response as Map);
        final success = data['success'] == true;

        if (success) {
          final serverId = data['message']?['_id'] as String? ?? '';
          if (serverId.isNotEmpty) {
            await _local.replaceTempId(
              tempId: tempId,
              serverId: serverId,
              status: 'sent',
            );
          } else {
            await _local.updateMessageStatus(tempId, 'sent');
          }

          await _local.updateConversationLastMessage(
            conversationId: activeConversationId!,
            messageId: serverId.isNotEmpty ? serverId : tempId,
            content: content,
            status: 'sent',
            senderId: _currentUserId!,
          );
        }
      },
    );
  }

  void sendTypingStatus(bool isTyping) {
    if (activeConversationId != null) {
      _socket.sendTypingStatus(activeConversationId!, isTyping);
    }
  }

  Future<void> loadMoreMessages() async {
    if (isLoadingMore || !hasMoreMessages || activeConversationId == null)
      return;
    if (activeMessages.isEmpty) return;

    isLoadingMore = true;
    notifyListeners();

    try {
      final oldest = activeMessages.first.createdAt;
      final older = await _local.getMessagesBefore(
        activeConversationId!,
        oldest,
        limit: 20,
      );

      if (older.isEmpty) {
        hasMoreMessages = false;
      } else {
        activeMessages = [...older.reversed.toList(), ...activeMessages];
      }
    } catch (e) {
      AppLogger.warn('ChatProvider: loadMoreMessages error — $e');
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> fetchConversations() async {
    await _syncManager
        .refreshConversations(currentUserId: _currentUserId ?? '')
        .catchError(
          (e) => AppLogger.warn('ChatProvider: fetchConversations — $e'),
        );
  }

  Future<void> fetchUsers() async {
    try {
      final remoteUsers = await _remote.getUsers();
      await _local.upsertUsers(remoteUsers);
    } catch (e) {
      AppLogger.warn('ChatProvider: fetchUsers error — $e');
    }
  }

  void _registerSocketHooks() {
    _socket.onIncomingMessage = (conversationId, data) async {
      try {
        final msg = MessageModel.fromJson(data);

        if (msg.sender.id == _currentUserId) return;

        await _local.saveMessageLocally(msg, isMine: false);
        await _local.updateConversationLastMessage(
          conversationId: conversationId,
          messageId: msg.id,
          content: msg.content,
          status: msg.status,
          senderId: msg.sender.id,
        );

        _socket.markAsDelivered(msg.id);

        if (activeConversationId == conversationId) {
          _socket.markAsRead(conversationId);
        }
      } catch (e) {
        AppLogger.error('ChatProvider: onIncomingMessage error — $e');
      }
    };

    _socket.onMessageStatusChanged = (messageId, status) async {
      await _local.updateMessageStatus(messageId, status);
    };

    _socket.onMessagesRead = (conversationId) async {
      final msgs = await _local.watchMessages(conversationId).first;
      for (final msg in msgs) {
        if (msg.sender.id != _currentUserId && msg.status != 'read') {
          await _local.updateMessageStatus(msg.id, 'read');
        }
      }
      await _local.updateConversationLastMessageStatus(conversationId, 'read');
    };

    _socket.onTypingChanged = (conversationId, userName, isTyping) {
      if (activeConversationId == conversationId) {
        typingUserName = isTyping ? userName : null;
        notifyListeners();
      }
    };

    _socket.onUserStatusChanged = (userId, isOnline, lastSeen) async {
      await _local.updateUserOnlineStatus(
        userId: userId,
        isOnline: isOnline,
        lastSeen: lastSeen,
      );
    };
  }

  void _onSocketStateChanged() {
    notifyListeners(); // Let ConnectionStatusBanner rebuild
  }

  UserModel _buildCurrentUserModel() {
    for (final convo in conversations) {
      final me = convo.participants.where((p) => p.id == _currentUserId);
      if (me.isNotEmpty) return me.first;
    }

    return UserModel(
      id: _currentUserId ?? '',
      name: 'Me',
      email: '',
      profileImage: '',
      isOnline: true,
      lastSeen: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _conversationsSub?.cancel();
    _messagesSub?.cancel();
    _usersSub?.cancel();
    _socket.connectionState.removeListener(_onSocketStateChanged);
    _pendingQueue.stopMonitoring();

    _socket.onIncomingMessage = null;
    _socket.onMessageStatusChanged = null;
    _socket.onMessagesRead = null;
    _socket.onTypingChanged = null;
    _socket.onUserStatusChanged = null;
    super.dispose();
  }
}
