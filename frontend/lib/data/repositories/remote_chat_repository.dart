import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class MessagesPage {
  final List<MessageModel> messages;
  final bool hasMore;
  MessagesPage({required this.messages, required this.hasMore});
}

class RemoteChatRepository {
  final ApiClient _apiClient;

  RemoteChatRepository(this._apiClient);

  Future<List<ConversationModel>> getConversations() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.conversations);
      final List data = response.data['conversations'] ?? [];
      return data
          .map((c) => ConversationModel.fromJson(c as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch conversations.',
      );
    }
  }

  Future<ConversationModel> createOrGetConversation({
    required String participantId,
    bool isGroup = false,
    String? groupName,
    List<String>? participants,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.conversations,
        data: {
          if (!isGroup) 'participantId': participantId,
          'isGroup': isGroup,
          if (isGroup) 'groupName': groupName,
          if (isGroup && participants != null) 'participants': participants,
        },
      );
      return ConversationModel.fromJson(response.data['conversation']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to setup thread.');
    }
  }

  Future<MessagesPage> getMessages(
    String conversationId, {
    String? beforeId,
    int limit = 30,
  }) async {
    try {
      final response = await _apiClient.dio.get(
        ApiEndpoints.messages(conversationId),
        queryParameters: {
          'limit': limit,
          if (beforeId != null) 'beforeId': beforeId,
        },
      );
      final List data = response.data['messages'] ?? [];
      final bool hasMore = response.data['hasMore'] ?? false;
      return MessagesPage(
        messages: data
            .map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
            .toList(),
        hasMore: hasMore,
      );
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to fetch messages.',
      );
    }
  }

  Future<List<UserModel>> getUsers() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.users);
      final List data = response.data['users'] ?? [];
      return data
          .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to fetch users.');
    }
  }
}
