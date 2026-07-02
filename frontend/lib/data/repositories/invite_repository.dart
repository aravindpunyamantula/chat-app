import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/conversation_model.dart';
import '../models/user_model.dart';

class InviteStatus {
  final bool bonded;
  final String? conversationId;
  final UserModel? partner;
  final String? myCode;
  final DateTime? expiresAt;

  const InviteStatus({
    required this.bonded,
    this.conversationId,
    this.partner,
    this.myCode,
    this.expiresAt,
  });
}

class InviteRepository {
  final ApiClient _apiClient;

  InviteRepository(this._apiClient);

  Future<InviteStatus> getStatus() async {
    try {
      final response = await _apiClient.dio.get(ApiEndpoints.inviteStatus);
      final data = response.data as Map<String, dynamic>;

      return InviteStatus(
        bonded: data['bonded'] as bool? ?? false,
        conversationId: data['conversationId']?.toString(),
        partner: data['partner'] != null && data['partner'] is Map
            ? UserModel.fromJson(data['partner'] as Map<String, dynamic>)
            : null,
        myCode: data['myCode'] as String?,
        expiresAt: data['expiresAt'] != null
            ? DateTime.tryParse(data['expiresAt'].toString())
            : null,
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to get invite status.');
    }
  }

  Future<({ConversationModel conversation, UserModel partner})> acceptInvite(
    String code,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.inviteAccept,
        data: {'code': code.trim().toUpperCase()},
      );
      final data = response.data as Map<String, dynamic>;
      final conversation = ConversationModel.fromJson(
        data['conversation'] as Map<String, dynamic>,
      );
      final partner = UserModel.fromJson(
        data['partner'] as Map<String, dynamic>,
      );
      return (conversation: conversation, partner: partner);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to accept invite.');
    }
  }

  Future<String> refreshCode() async {
    try {
      final response = await _apiClient.dio.post(ApiEndpoints.inviteRefreshCode);
      return response.data['myCode'] as String;
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Failed to refresh code.');
    }
  }
}
