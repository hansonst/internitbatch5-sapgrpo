import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:gr_po_oji/models/api_models.dart';
import 'auth_service.dart';

class SapApiService {
  static const String baseUrl = 'http://192.102.30.79:8000/api';
  
  // Singleton pattern
  static final SapApiService _instance = SapApiService._internal();
  factory SapApiService() => _instance;
  SapApiService._internal();

  // Auth service instance
  final _authService = AuthService();

  // Callback for automatic logout on 401
  Function()? onUnauthorized;

  /// Initialize service
  Future<void> initialize() async {
    await _authService.initialize();
    print('📱 API Service initialized - Authenticated: ${_authService.isAuthenticated}');
  }

  /// Get headers with automatic token injection
  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth && _authService.authHeader != null) {
      headers['Authorization'] = _authService.authHeader!;
      print('🔑 Request with token: ${_authService.token?.substring(0, 20)}...');
    } else {
      print('⚠️ Request without token');
    }

    return headers;
  }

  /// Handle API response with automatic 401 handling
  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else if (response.statusCode == 401) {
      // Token expired or invalid - trigger logout
      print('🚨 401 Unauthorized - Auto logout triggered');
      _authService.clearAuthData();
      
      // Call the logout callback if set
      if (onUnauthorized != null) {
        onUnauthorized!();
      }
      
      throw ApiException(
        message: 'Session expired. Please login again.',
        statusCode: 401,
      );
    } else {
      throw ApiException(
        message: data['message'] ?? 'An error occurred',
        statusCode: response.statusCode,
        errors: data['errors'],
      );
    }
  }

  // ============= AUTHENTICATION METHODS =============

  /// Login user with username/password
  Future<LoginResponse> login({
    required String userId,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sap/login'),
        headers: _getHeaders(includeAuth: false),
        body: json.encode({
          'user_id': userId,
          'password': password,
        }),
      );

      final data = _handleResponse(response);

      if (data['success'] == true) {
  final loginResponse = LoginResponse.fromJson(data);
  
  // Save auth data to secure storage
  await _authService.saveAuthData(
    token: loginResponse.token,  //    CORRECT
    userId: loginResponse.userData.userId,
    userName: loginResponse.userData.fullName,
    department: loginResponse.userData.department,
  );
  
  print('   Login successful for: ${loginResponse.userData.userId}');
  return loginResponse;
      } else {
        throw ApiException(
          message: data['message'] ?? 'Login failed',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Login with RFID card
Future<LoginResponse> loginWithRfid({
  required String idCard,
}) async {
  print('🔍 ========== RFID LOGIN DEBUG START ==========');
  print('🔍 RFID Card ID: $idCard');
  print('🔍 Base URL: $baseUrl');
  print('🔍 Full URL: $baseUrl/sap/login-rfid');
  
  try {
    // Prepare request data
    final requestBody = {
      'id_card': idCard,
    };
    print('🔍 Request body: ${json.encode(requestBody)}');
    print('🔍 Request headers: ${_getHeaders(includeAuth: false)}');
    
    // Make the request
    print('🔍 Sending POST request...');
    final response = await http.post(
      Uri.parse('$baseUrl/sap/login-rfid'),
      headers: _getHeaders(includeAuth: false),
      body: json.encode(requestBody),
    );

    // Log response details
    print('📊 Response Status Code: ${response.statusCode}');
    print('📊 Response Headers: ${response.headers}');
    print('📊 Response Body (raw): ${response.body}');
    
    // Check for 500 error specifically
    if (response.statusCode == 500) {
      print('❌ ========== SERVER ERROR 500 DETECTED ==========');
      print('❌ Server returned 500 Internal Server Error');
      print('❌ Response body: ${response.body}');
      
      // Try to parse error message if exists
      try {
        final errorData = json.decode(response.body);
        print('❌ Parsed error data: $errorData');
        print('❌ Error message: ${errorData['message'] ?? 'No message'}');
        print('❌ Error details: ${errorData['detail'] ?? 'No details'}');
      } catch (parseError) {
        print('❌ Could not parse error response: $parseError');
      }
      
      throw ApiException(
        message: 'Server error (500). Please check backend logs for: RFID=$idCard',
        statusCode: 500,
      );
    }

    // Handle response
    print('🔍 Attempting to parse response...');
    final data = _handleResponse(response);
    print('🔍 Parsed response data: $data');

    if (data['success'] == true) {
      print('   Login success flag detected');
      
      final loginResponse = LoginResponse.fromJson(data);
      print('   LoginResponse created');
      print('   Token: ${loginResponse.token.substring(0, 20)}...'); // Show first 20 chars
      print('   User ID: ${loginResponse.userData.userId}');
      print('   Full Name: ${loginResponse.userData.fullName}');
      print('   Department: ${loginResponse.userData.department}');
      
      // Save auth data to secure storage
      print('🔍 Saving auth data to secure storage...');
      try {
        await _authService.saveAuthData(
          token: loginResponse.token,
          userId: loginResponse.userData.userId,
          userName: loginResponse.userData.fullName,
          department: loginResponse.userData.department,
        );
        print('   Auth data saved successfully');
      } catch (storageError) {
        print('❌ Error saving auth data: $storageError');
        print('❌ Storage error stack trace: ${storageError}');
        // Don't throw here - user is authenticated, storage is secondary
      }
      
      print('   RFID login successful for: ${loginResponse.userData.userId}');
      print('🔍 ========== RFID LOGIN DEBUG END (SUCCESS) ==========');
      return loginResponse;
      
    } else {
      print('❌ Login failed - success flag is false');
      print('❌ Response data: $data');
      
      throw ApiException(
        message: data['message'] ?? 'RFID login failed',
        statusCode: response.statusCode,
      );
    }
    
  } on ApiException catch (e) {
    print('❌ API Exception caught');
    print('❌ Message: ${e.message}');
    print('❌ Status Code: ${e.statusCode}');
    print('🔍 ========== RFID LOGIN DEBUG END (API ERROR) ==========');
    rethrow;
    
  } on http.ClientException catch (e) {
    print('❌ HTTP Client Exception');
    print('❌ Error: $e');
    print('❌ Could not connect to server');
    print('❌ Check if backend is running at: $baseUrl');
    print('🔍 ========== RFID LOGIN DEBUG END (CONNECTION ERROR) ==========');
    rethrow;
    
  } on FormatException catch (e) {
    print('❌ Format Exception - JSON parsing failed');
    print('❌ Error: $e');
    print('❌ This usually means the server returned non-JSON data');
    print('🔍 ========== RFID LOGIN DEBUG END (PARSE ERROR) ==========');
    rethrow;
    
  } catch (e, stackTrace) {
    print('❌ Unexpected error during RFID login');
    print('❌ Error type: ${e.runtimeType}');
    print('❌ Error: $e');
    print('❌ Stack trace: $stackTrace');
    print('🔍 ========== RFID LOGIN DEBUG END (UNEXPECTED ERROR) ==========');
    rethrow;
  }
}

  /// Logout current session
  Future<Map<String, dynamic>> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sap/logout'),
        headers: _getHeaders(),
      );

      final data = _handleResponse(response);
      await _authService.clearAuthData();
      
      print('   Logout successful');
      return data;
    } catch (e) {
      // Even if API call fails, clear local auth data
      await _authService.clearAuthData();
      rethrow;
    }
  }

  /// Logout all sessions
  Future<Map<String, dynamic>> logoutAll() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sap/logout-all'),
        headers: _getHeaders(),
      );

      final data = _handleResponse(response);
      await _authService.clearAuthData();
      
      print('   Logout all sessions successful');
      return data;
    } catch (e) {
      await _authService.clearAuthData();
      rethrow;
    }
  }

  /// Get user profile
  Future<UserProfile> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sap/profile'),
        headers: _getHeaders(),
      );

      final data = _handleResponse(response);
      return UserProfile.fromJson(data['data']);
    } catch (e) {
      rethrow;
    }
  }

  /// Check authentication status
  Future<Map<String, dynamic>> checkAuth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sap/check-auth'),
        headers: _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _authService.isAuthenticated;
  }

  /// Get current user info from storage (without API call)
  Map<String, String?> getCurrentUser() {
    return {
      'userId': _authService.userId,
      'userName': _authService.userName,
      'department': _authService.department,
    };
  }

  // ============= PURCHASE ORDER METHODS =============

  Future<PurchaseOrderResponse> getPurchaseOrders({required String poNo}) async {
    try {
      final url = '$baseUrl/sap/purchase-orders?po_no=$poNo';
      print('🌐 Requesting PO: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      print('📡 Status: ${response.statusCode}');
      final data = _handleResponse(response);
      return PurchaseOrderResponse.fromJson(data);
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  Future<RfidVerificationResponse> verifyRfid({
    required String idCard,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sap/verify-rfid'),
        headers: _getHeaders(),
        body: json.encode({
          'id_card': idCard,
        }),
      );

      final data = _handleResponse(response);
      return RfidVerificationResponse.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }
  
  Future<GoodReceiptResponse> createGoodReceipt({
    required String idCard,
    String? dnNo,
    required String docDate,
    required String postDate,
    required String poNo,
    required String itemPo,
    required String qty,
    required String plant,
    String? sloc,
    String? batchNo,
    String? dom,
  }) async {
    return await createGoodReceiptBatch(
      idCard: idCard,
      dnNo: dnNo ?? '',
      docDate: docDate,
      postDate: postDate,
      items: [
        GoodReceiptItem(
          poNo: poNo,
          itemPo: itemPo,
          qty: double.parse(qty),
          plant: plant,
          sloc: sloc,
          batchNo: batchNo,
          dom: dom,
        )
      ],
    );
  }

  Future<GoodReceiptResponse> createGoodReceiptBatch({
    required String idCard,
    required String dnNo,
    required String docDate,
    required String postDate,
    required List<GoodReceiptItem> items,
  }) async {
    try {
      final itemsPayload = items.map((item) => {
        'po_no': item.poNo,
        'item_po': item.itemPo,
        'qty': item.qty.toString(),
        'plant': item.plant,
        'sloc': item.sloc ?? '',
        'batch_no': item.batchNo ?? '',
        'dom': item.dom ?? '',
      }).toList();

      final payload = {
        'id_card': idCard,
        'dn_no': dnNo,
        'doc_date': docDate,
        'post_date': postDate,
        'items': itemsPayload,
      };

      print('🚀 Creating GR Batch with ${items.length} items');
      print('📦 Payload: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse('$baseUrl/sap/good-receipts'),
        headers: _getHeaders(),
        body: json.encode(payload),
      );

      print('📡 GR Response Status: ${response.statusCode}');
      final data = _handleResponse(response);
      return GoodReceiptResponse.fromJson(data);
    } catch (e) {
      print('❌ GR Batch Error: $e');
      rethrow;
    }
  }

  // ============= GR HISTORY METHODS =============

  Future<GrHistoryResponse> getGrHistory({required String poNo}) async {
    try {
      final url = '$baseUrl/sap/gr-history?po_no=$poNo';
      print('🌐 Requesting GR History: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      print('📡 GR History Status: ${response.statusCode}');
      final data = _handleResponse(response);
      return GrHistoryResponse.fromJson(data);
    } catch (e) {
      print('❌ GR History Error: $e');
      rethrow;
    }
  }

  Future<GrHistoryResponse> getGrHistoryByItem({
    required String poNo,
    required String itemPo,
  }) async {
    try {
      final url = '$baseUrl/sap/gr-history-by-item?po_no=$poNo&item_po=$itemPo';
      print('🌐 Requesting GR History by Item: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      print('📡 GR History by Item Status: ${response.statusCode}');
      final data = _handleResponse(response);
      return GrHistoryResponse.fromJson(data);
    } catch (e) {
      print('❌ GR History by Item Error: $e');
      rethrow;
    }
  }

  Future<GrDropdownValuesResponse> getGrDropdownValues({
    required String poNo,
    String? itemPo,
  }) async {
    try {
      var url = '$baseUrl/sap/gr-dropdown-values?po_no=$poNo';
      if (itemPo != null && itemPo.isNotEmpty) {
        url += '&item_po=$itemPo';
      }

      print('🌐 Requesting GR Dropdown Values: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      print('📡 GR Dropdown Values Status: ${response.statusCode}');
      final data = _handleResponse(response);
      return GrDropdownValuesResponse.fromJson(data);
    } catch (e) {
      print('❌ GR Dropdown Values Error: $e');
      rethrow;
    }
  }
}