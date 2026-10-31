import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/crypto/crypto_service.dart';
import 'core/api/auth_api.dart';
import 'core/api/users_api.dart';
import 'core/api/chat_websocket.dart';
import 'core/api/settings_api.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/auth_state.dart';
import 'core/chat/chat_controller.dart';
import 'screens/auth/login_screen.dart';
import 'screens/chat/conversations_screen.dart';

const String backendUrl = 'http://192.168.1.17:3000';
const String wsUrl = 'ws://192.168.1.17:3000';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final crypto = await CryptoService.init();
  final storage = SecureStorageService();
  final authApi = AuthApi(baseUrl: backendUrl);
  final usersApi = UsersApi(baseUrl: backendUrl);
  final settingsApi = SettingsApi(baseUrl: backendUrl);
  final authRepository =
      AuthRepository(crypto: crypto, api: authApi, storage: storage);

  runApp(MyApp(
    authRepository: authRepository,
    storage: storage,
    crypto: crypto,
    usersApi: usersApi,
    settingsApi: settingsApi,
  ));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  final SecureStorageService storage;
  final CryptoService crypto;
  final UsersApi usersApi;
  final SettingsApi settingsApi;

  const MyApp({
    super.key,
    required this.authRepository,
    required this.storage,
    required this.crypto,
    required this.usersApi,
    required this.settingsApi,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SecureStorageService>.value(value: storage),
        Provider<SettingsApi>.value(value: settingsApi),
        ChangeNotifierProvider(
          create: (_) => AuthState(repository: authRepository, storage: storage)
            ..checkExistingSession(),
        ),
        ChangeNotifierProxyProvider<AuthState, ChatController?>(
          create: (_) => null,
          update: (_, authState, previous) {
            if (authState.status != AuthStatus.authenticated) return null;
            if (previous != null) return previous;

            final controller = ChatController(
              crypto: crypto,
              storage: storage,
              usersApi: usersApi,
              ws: ChatWebSocket(wsUrl: wsUrl),
            );
            storage.getToken().then((token) {
              storage.getUserId().then((userId) {
                if (token != null && userId != null) {
                  controller.init(token: token, myUserId: userId);
                }
              });
            });
            return controller;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Family Chat',
        theme: ThemeData(colorSchemeSeed: Colors.deepPurple, useMaterial3: true),
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    switch (authState.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        final chatController = context.watch<ChatController?>();
        if (chatController == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return ChangeNotifierProvider.value(
          value: chatController,
          child: const ConversationsScreen(),
        );
    }
  }
}