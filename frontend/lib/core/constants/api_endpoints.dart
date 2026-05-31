class ApiEndpoints {
  static const String baseUrl = 'http://localhost:5000/api';
  static const String wsUrl = 'ws://localhost:5000';

  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String profile = '/auth/profile';
  static const String users = '/auth/users';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  static const String conversations = '/chat/conversations';
  static String messages(String conversationId) =>
      '/chat/conversations/$conversationId/messages';
}
