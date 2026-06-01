import 'package:dio/dio.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/services/storage_service.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    String? profileImage,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.register,
        data: {
          'name': name,
          'email': email,
          'password': password,
          if (profileImage != null) 'profileImage': profileImage,
        },
      );

      final data = response.data;
      final accessToken = data['accessToken'];
      final refreshToken = data['refreshToken'];

      await StorageService.saveToken(accessToken);
      await StorageService.saveRefreshToken(refreshToken);

      return UserModel.fromJson(data['user']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Registration failed.');
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );

      final data = response.data;
      final accessToken = data['accessToken'];
      final refreshToken = data['refreshToken'];

      await StorageService.saveToken(accessToken);
      await StorageService.saveRefreshToken(refreshToken);

      return UserModel.fromJson(data['user']);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? 'Login failed.');
    }
  }

  Future<UserModel?> getProfile() async {
    try {
      final token = await StorageService.getToken();
      if (token == null) return null;

      final response = await _apiClient.dio.get(ApiEndpoints.profile);
      return UserModel.fromJson(response.data['user']);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['message'] ?? 'Failed to retrieve profile.',
      );
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _apiClient.dio.post(
          ApiEndpoints.logout,
          data: {'refreshToken': refreshToken},
        );
      }
    } catch (_) {
    } finally {
      await StorageService.clearAuthData();
    }
  }
}
