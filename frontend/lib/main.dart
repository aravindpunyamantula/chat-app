import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/network/api_client.dart';
import 'core/network/socket_service.dart';
import 'core/services/sync_manager.dart';
import 'core/services/pending_queue_service.dart';

import 'data/local/app_database.dart';

import 'data/repositories/auth_repository.dart';
import 'data/repositories/local_chat_repository.dart';
import 'data/repositories/remote_chat_repository.dart';

import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';

import 'views/auth/login_view.dart';
import 'views/chat/inbox_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();

  runApp(MyApp(db: db));
}

class MyApp extends StatelessWidget {
  final AppDatabase db;

  const MyApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    final socketService = SocketService();

    final authRepository = AuthRepository(apiClient);
    final localChatRepo = LocalChatRepository(db);
    final remoteChatRepo = RemoteChatRepository(apiClient);

    final syncManager = SyncManager(
      local: localChatRepo,
      remote: remoteChatRepo,
    );
    final pendingQueue = PendingQueueService(
      local: localChatRepo,
      socket: socketService,
    );

    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<ApiClient>.value(value: apiClient),
        Provider<SocketService>.value(value: socketService),
        Provider<LocalChatRepository>.value(value: localChatRepo),
        Provider<RemoteChatRepository>.value(value: remoteChatRepo),
        Provider<SyncManager>.value(value: syncManager),
        Provider<PendingQueueService>.value(value: pendingQueue),
        Provider<AuthRepository>.value(value: authRepository),

        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(authRepository),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(
            local: localChatRepo,
            remote: remoteChatRepo,
            socket: socketService,
            syncManager: syncManager,
            pendingQueue: pendingQueue,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Chat App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007AFF),
            brightness: Brightness.light,
          ),
          textTheme: GoogleFonts.interTextTheme(),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF007AFF),
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading && authProvider.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading…', style: TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    if (authProvider.isAuthenticated) {
      final socketService = Provider.of<SocketService>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id ?? '';

      if (!_initialized && userId.isNotEmpty) {
        _initialized = true;

        socketService.connect();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          chatProvider.initialize(userId);
        });
      }

      return const InboxView();
    }

    _initialized = false;
    return const LoginView();
  }
}
