import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../data/repositories/local_chat_repository.dart';
import '../../data/models/message_model.dart';
import '../network/socket_service.dart';
import '../utils/logger.dart';

class PendingQueueService {
  final LocalChatRepository _local;
  final SocketService _socket;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isFlushing = false;

  PendingQueueService({
    required LocalChatRepository local,
    required SocketService socket,
  }) : _local = local,
       _socket = socket;

  void startMonitoring() {
    _socket.connectionState.addListener(_onSocketStateChanged);

    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        AppLogger.info('PendingQueue: connectivity restored — flushing queue');
        flushPending();
      }
    });
  }

  void stopMonitoring() {
    _socket.connectionState.removeListener(_onSocketStateChanged);
    _connectivitySub?.cancel();
  }

  Future<void> flushPending() async {
    if (_isFlushing) return;
    if (_socket.connectionState.value != SocketConnectionState.connected)
      return;

    _isFlushing = true;
    try {
      final pending = await _local.getPendingMessages();
      if (pending.isEmpty) {
        AppLogger.info('PendingQueue: nothing to flush');
        return;
      }

      AppLogger.info('PendingQueue: flushing ${pending.length} messages');

      for (final msg in pending) {
        await _sendPendingMessage(msg);

        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      AppLogger.warn('PendingQueue: flush error — $e');
    } finally {
      _isFlushing = false;
    }
  }

  void _onSocketStateChanged() {
    if (_socket.connectionState.value == SocketConnectionState.connected) {
      flushPending();
    }
  }

  Future<void> _sendPendingMessage(MessageModel msg) async {
    _socket.sendMessage(
      {
        'conversationId': msg.conversationId,
        'content': msg.content,
        'tempId': msg.id, // server echoes this back in ack
        'messageType': msg.messageType,
      },
      ack: (dynamic response) async {
        if (response == null) return;
        final data = Map<String, dynamic>.from(response as Map);
        final success = data['success'] == true;

        if (success) {
          final serverId = data['message']?['_id'] as String?;
          if (serverId != null && serverId.isNotEmpty) {
            await _local.replaceTempId(
              tempId: msg.id,
              serverId: serverId,
              status: 'sent',
            );
          } else {
            await _local.updateMessageStatus(msg.id, 'sent');
          }
          AppLogger.info('PendingQueue: message ${msg.id} → sent ($serverId)');
        } else {
          AppLogger.warn('PendingQueue: message ${msg.id} — ack failed');
        }
      },
    );
  }
}
