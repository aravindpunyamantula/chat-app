import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_endpoints.dart';
import '../services/storage_service.dart';
import '../utils/logger.dart';

enum SocketConnectionState { connecting, connected, disconnected }

class SocketService {
  io.Socket? _socket;

  final ValueNotifier<SocketConnectionState> connectionState =
      ValueNotifier<SocketConnectionState>(SocketConnectionState.disconnected);

  io.Socket? get socket => _socket;

  void Function(String conversationId, Map<String, dynamic> messageData)?
  onIncomingMessage;

  void Function(String messageId, String status)? onMessageStatusChanged;

  void Function(String conversationId)? onMessagesRead;

  void Function(String conversationId, String userName, bool isTyping)?
  onTypingChanged;

  void Function(String userId, bool isOnline, DateTime? lastSeen)?
  onUserStatusChanged;

  void connect() async {
    final token = await StorageService.getToken();
    if (token == null) return;

    connectionState.value = SocketConnectionState.connecting;

    _socket = io.io(
      ApiEndpoints.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .enableForceNew()
          .setReconnectionAttempts(99999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setAuth({'token': token})
          .build(),
    );

    _socket?.connect();

    _socket?.onConnect((_) {
      AppLogger.info('Socket connected.', tag: 'SOCKET');
      connectionState.value = SocketConnectionState.connected;
    });

    _socket?.onDisconnect((_) {
      AppLogger.warn('Socket disconnected.', tag: 'SOCKET');
      connectionState.value = SocketConnectionState.disconnected;
    });

    _socket?.onConnectError((err) {
      AppLogger.error('Socket connect error: $err', tag: 'SOCKET');
      connectionState.value = SocketConnectionState.connecting;
    });

    _socket?.onReconnectAttempt((_) {
      AppLogger.info('Socket reconnecting…', tag: 'SOCKET');
      connectionState.value = SocketConnectionState.connecting;
    });

    _socket?.onReconnectFailed((_) {
      AppLogger.warn('Socket reconnect failed.', tag: 'SOCKET');
      connectionState.value = SocketConnectionState.disconnected;
    });

    _registerInboundHandlers();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    connectionState.value = SocketConnectionState.disconnected;
  }

  void joinConversation(String conversationId) {
    _socket?.emit('join_conversation', conversationId);
  }

  void leaveConversation(String conversationId) {
    _socket?.emit('leave_conversation', conversationId);
  }

  void sendTypingStatus(String conversationId, bool isTyping) {
    _socket?.emit('typing', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  void sendMessage(Map<String, dynamic> messageData, {Function(dynamic)? ack}) {
    if (ack != null) {
      _socket?.emitWithAck('send_message', messageData, ack: ack);
    } else {
      _socket?.emit('send_message', messageData);
    }
  }

  void markAsDelivered(String messageId) {
    _socket?.emit('message_delivered', {'messageId': messageId});
  }

  void markAsRead(String conversationId) {
    _socket?.emit('message_read', {'conversationId': conversationId});
  }

  void _registerInboundHandlers() {
    _socket?.on('new_message', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        final conversationId = map['conversationId'] as String? ?? '';
        AppLogger.info('Socket: new_message in $conversationId', tag: 'SOCKET');
        onIncomingMessage?.call(conversationId, map);
      } catch (e) {
        AppLogger.error('Socket: new_message parse error — $e', tag: 'SOCKET');
      }
    });

    _socket?.on('message_status_updated', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        final messageId = map['messageId'] as String? ?? '';
        final status = map['status'] as String? ?? 'sent';
        onMessageStatusChanged?.call(messageId, status);
      } catch (e) {
        AppLogger.error(
          'Socket: message_status_updated error — $e',
          tag: 'SOCKET',
        );
      }
    });

    _socket?.on('messages_read_receipt', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        final conversationId = map['conversationId'] as String? ?? '';
        onMessagesRead?.call(conversationId);
      } catch (e) {
        AppLogger.error(
          'Socket: messages_read_receipt error — $e',
          tag: 'SOCKET',
        );
      }
    });

    _socket?.on('user_typing', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        final conversationId = map['conversationId'] as String? ?? '';
        final userName = map['userName'] as String? ?? '';
        final isTyping = map['isTyping'] as bool? ?? false;
        onTypingChanged?.call(conversationId, userName, isTyping);
      } catch (e) {
        AppLogger.error('Socket: user_typing error — $e', tag: 'SOCKET');
      }
    });

    _socket?.on('user_status_changed', (data) {
      try {
        final map = Map<String, dynamic>.from(data as Map);
        final userId = map['userId'] as String? ?? '';
        final isOnline = map['isOnline'] as bool? ?? false;
        final lastSeenStr = map['lastSeen'] as String?;
        final lastSeen = lastSeenStr != null
            ? DateTime.tryParse(lastSeenStr)
            : null;
        onUserStatusChanged?.call(userId, isOnline, lastSeen);
      } catch (e) {
        AppLogger.error(
          'Socket: user_status_changed error — $e',
          tag: 'SOCKET',
        );
      }
    });
  }
}
