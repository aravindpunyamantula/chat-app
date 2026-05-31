import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import '../services/storage_service.dart';

class ApiClient {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiEndpoints.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  static void Function()? onAuthenticationRequired;

  ApiClient() {
    _initializeInterceptors();
  }

  Dio get dio => _dio;

  void _initializeInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            final requestPath = e.requestOptions.path;

            if (requestPath.contains('/auth/refresh') ||
                requestPath.contains('/auth/login') ||
                requestPath.contains('/auth/register')) {
              return handler.next(e);
            }

            final refreshToken = await StorageService.getRefreshToken();
            if (refreshToken != null && refreshToken.isNotEmpty) {
              try {
                final refreshDio = Dio(
                  BaseOptions(
                    baseUrl: ApiEndpoints.baseUrl,
                    headers: {'Content-Type': 'application/json'},
                  ),
                );

                final response = await refreshDio.post(
                  ApiEndpoints.refresh,
                  data: {'refreshToken': refreshToken},
                );

                if (response.statusCode == 200 &&
                    response.data['success'] == true) {
                  final data = response.data;
                  final newAccessToken = data['accessToken'];
                  final newRefreshToken = data['refreshToken'];

                  await StorageService.saveToken(newAccessToken);
                  await StorageService.saveRefreshToken(newRefreshToken);

                  e.requestOptions.headers['Authorization'] =
                      'Bearer $newAccessToken';

                  final retryResponse = await _dio.fetch(e.requestOptions);
                  return handler.resolve(retryResponse);
                }
              } catch (refreshError) {
                await StorageService.clearAuthData();
                onAuthenticationRequired?.call();
                return handler.next(e);
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }
}
