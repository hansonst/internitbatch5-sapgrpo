import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure authentication token management service
class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Secure storage instance
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Storage keys
  static const String _tokenKey = 'sap_auth_token';
  static const String _userIdKey = 'sap_user_id';
  static const String _userNameKey = 'sap_user_name';
  static const String _departmentKey = 'sap_department';

  // In-memory cache for performance
  String? _cachedToken;
  String? _cachedUserId;
  String? _cachedUserName;
  String? _cachedDepartment;

  /// Initialize and load cached values
  Future<void> initialize() async {
    _cachedToken = await _storage.read(key: _tokenKey);
    _cachedUserId = await _storage.read(key: _userIdKey);
    _cachedUserName = await _storage.read(key: _userNameKey);
    _cachedDepartment = await _storage.read(key: _departmentKey);
    
    print('🔐 Auth initialized - Token exists: ${_cachedToken != null}');
  }

  /// Save authentication data after login
  Future<void> saveAuthData({
    required String token,
    required String userId,
    required String userName,
    String? department,
  }) async {
    _cachedToken = token;
    _cachedUserId = userId;
    _cachedUserName = userName;
    _cachedDepartment = department;

    await Future.wait([
      _storage.write(key: _tokenKey, value: token),
      _storage.write(key: _userIdKey, value: userId),
      _storage.write(key: _userNameKey, value: userName),
      if (department != null) _storage.write(key: _departmentKey, value: department),
    ]);

    print('✅ Auth data saved for user: $userId');
  }

  /// Clear all authentication data (logout)
  Future<void> clearAuthData() async {
    _cachedToken = null;
    _cachedUserId = null;
    _cachedUserName = null;
    _cachedDepartment = null;

    await _storage.deleteAll();
    print('🗑️ Auth data cleared');
  }

  /// Get current token
  String? get token => _cachedToken;

  /// Get current user ID
  String? get userId => _cachedUserId;

  /// Get current user name
  String? get userName => _cachedUserName;

  /// Get current department
  String? get department => _cachedDepartment;

  /// Check if user is authenticated
  bool get isAuthenticated => _cachedToken != null && _cachedToken!.isNotEmpty;

  /// Get authorization header
  String? get authHeader => _cachedToken != null ? 'Bearer $_cachedToken' : null;
}