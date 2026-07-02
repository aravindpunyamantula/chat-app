import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/network/api_client.dart';
import 'core/network/socket_service.dart';
import 'core/services/sync_manager.dart';
import 'core/services/pending_queue_service.dart';

import 'data/local/app_database.dart';

import 'data/repositories/auth_repository.dart';
import 'data/repositories/invite_repository.dart';
import 'data/repositories/local_chat_repository.dart';
import 'data/repositories/remote_chat_repository.dart';

import 'providers/app_lock_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/invite_provider.dart';

import 'views/auth/lock_screen.dart';
import 'views/auth/login_view.dart';
import 'views/chat/chat_room_view.dart';
import 'views/invite/invite_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final appLock = AppLockProvider();
  await appLock.initialize();

  runApp(MyApp(db: db, appLock: appLock));
}

class MyApp extends StatelessWidget {
  final AppDatabase db;
  final AppLockProvider appLock;

  const MyApp({super.key, required this.db, required this.appLock});

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
        ChangeNotifierProvider<AppLockProvider>.value(value: appLock),
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
        ChangeNotifierProvider<InviteProvider>(
          create: (_) => InviteProvider(
            repo: InviteRepository(apiClient),
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
        home: const AppLockWrapper(),
      ),
    );
  }
}

/// Sits above everything. Shows LockScreen until unlocked, then shows AuthWrapper.
/// Re-locks when the app is backgrounded for more than 30 seconds.
class AppLockWrapper extends StatefulWidget {
  const AppLockWrapper({super.key});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

  static const _autoLockSeconds = 30;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = Provider.of<AppLockProvider>(context, listen: false);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundedAt != null) {
        final elapsed = DateTime.now().difference(_backgroundedAt!).inSeconds;
        if (elapsed >= _autoLockSeconds && lock.isUnlocked) {
          lock.lock();
        }
      }
      _backgroundedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lock = Provider.of<AppLockProvider>(context);

    if (lock.isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!lock.isUnlocked) {
      return const LockScreen();
    }

    return const AuthWrapper();
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _initialized = false;

  static const Widget _loading = Scaffold(
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading && authProvider.currentUser == null) {
      return _loading;
    }

    if (authProvider.isAuthenticated) {
      final socketService = Provider.of<SocketService>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final inviteProvider = Provider.of<InviteProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id ?? '';

      if (!_initialized && userId.isNotEmpty) {
        _initialized = true;
        socketService.connect();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          chatProvider.initialize(userId);
          inviteProvider.checkStatus();
        });
      }

      return Consumer<InviteProvider>(
        builder: (ctx, invite, _) {
          // isChecking is now true for both idle and checking states
          if (invite.isChecking) return _loading;

          // Bonded — go straight to chat
          if (invite.isBonded && invite.bondedConversation != null) {
            return _BondedHome(
              conversationId: invite.bondedConversation!.id,
              partnerName: invite.partner?.name ?? 'Partner',
            );
          }

          // Not bonded yet — show invite / pairing screen
          return const InviteScreen();
        },
      );
    }

    _initialized = false;
    return const LoginView();
  }
}

/// Selects the bonded conversation once and stays in ChatRoomView.
class _BondedHome extends StatefulWidget {
  final String conversationId;
  final String partnerName;

  const _BondedHome({
    required this.conversationId,
    required this.partnerName,
  });

  @override
  State<_BondedHome> createState() => _BondedHomeState();
}

class _BondedHomeState extends State<_BondedHome> {
  bool _selected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_selected) {
        _selected = true;
        Provider.of<ChatProvider>(context, listen: false)
            .selectConversation(widget.conversationId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChatRoomView(conversationTitle: widget.partnerName);
  }
}
