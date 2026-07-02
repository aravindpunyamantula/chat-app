import 'package:flutter/foundation.dart' show kIsWeb;

class ApiEndpoints {
  // Web runs in the browser on the same machine → localhost works fine.
  // Android emulator maps 10.0.2.2 → host machine.
  // Real Android device: replace _androidHost with your LAN IP (e.g. 192.168.1.x).
  // Production: replace both with your HTTPS domain.
  static const String _webHost = 'http://localhost:5000';
  static const String _androidHost = 'http://10.0.2.2:5000';

  static String get _host => kIsWeb ? _webHost : _androidHost;

  static String get baseUrl => '$_host/api';
  static String get wsUrl => kIsWeb ? 'http://localhost:5000' : 'http://10.0.2.2:5000';
  static String get mediaBaseUrl => _host;

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String profile = '/auth/profile';
  static const String users = '/auth/users';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  // Chat
  static const String conversations = '/chat/conversations';
  static const String upload = '/chat/upload';
  static String messages(String conversationId) =>
      '/chat/conversations/$conversationId/messages';

  // Invite / Bonded pair
  static const String inviteStatus = '/invite/status';
  static const String inviteAccept = '/invite/accept';
  static const String inviteRefreshCode = '/invite/refresh-code';
}
