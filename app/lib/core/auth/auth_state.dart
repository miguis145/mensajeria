import 'package:flutter/foundation.dart';
import '../auth/auth_repository.dart';
import '../storage/secure_storage_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends ChangeNotifier {
  final AuthRepository _repository;
  final SecureStorageService _storage;

  AuthState({
    required AuthRepository repository,
    required SecureStorageService storage,
  })  : _repository = repository,
        _storage = storage;

  AuthStatus status = AuthStatus.unknown;
  String? username;
  String? userId;
  String? errorMessage;
  bool isLoading = false;

  /// Se llama al arrancar la app, para ver si ya hay sesión guardada.
  Future<void> checkExistingSession() async {
    final hasSession = await _repository.hasStoredSession();
    if (hasSession) {
      username = await _storage.getUsername();
      userId = await _storage.getUserId();
      status = AuthStatus.authenticated;
    } else {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> register(String usernameInput, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.register(username: usernameInput, password: password);
      username = usernameInput;
      userId = await _storage.getUserId();
      status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      errorMessage = _friendlyError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String usernameInput, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.login(username: usernameInput, password: password);
      username = usernameInput;
      userId = await _storage.getUserId();
      status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      errorMessage = _friendlyError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    username = null;
    userId = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Credenciales inválidas')) return 'Usuario o contraseña incorrectos';
    if (msg.contains('ya está en uso')) return 'Ese nombre de usuario ya existe';
    if (msg.contains('clave privada')) return msg.replaceAll('Exception: ', '');
    return 'Error de conexión. Verifica que el servidor esté disponible.';
  }
}