import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gr_po_oji/models/api_models.dart'; // Import the models

class SapApiService {
  // Base URL - Change this to your actual API URL
  static const String baseUrl = 'http://localhost/api';
  
  // Singleton pattern
  static final SapApiService _instance = SapApiService._internal();
  factory SapApiService() => _instance;
  SapApiService._internal();

  // Token management
  String? _token;
  
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('sap_auth_token');
    print('📱 Token loaded from storage: ${_token?.substring(0, 20) ?? "NULL"}');
  }

  /// Save token to SharedPreferences
  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sap_auth_token', token);
  }

  /// Clear token from SharedPreferences
  Future<void> _clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sap_auth_token');
  }

  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
      print('🔑 Token being sent: ${_token?.substring(0, 20)}...');
    } else {
      print('⚠️ No token available or auth not required');
    }

    return headers;
  }

  /// Handle API response
  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = json.decode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw ApiException(
        message: data['message'] ?? 'An error occurred',
        statusCode: response.statusCode,
        errors: data['errors'],
      );
    }
  }

  // ============= AUTHENTICATION METHODS =============

  /// Login user
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
        final token = data['data']['token'];
        await _saveToken(token);
        print('✅ Token saved: ${token.substring(0, 20)}...');
        print('✅ Token in memory: $_token');

        return LoginResponse.fromJson(data);
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

  /// Logout current session
  Future<Map<String, dynamic>> logout() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/sap/logout'),
        headers: _getHeaders(),
      );

      final data = _handleResponse(response);
      await _clearToken();
      return data;
    } catch (e) {
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
      await _clearToken();
      return data;
    } catch (e) {
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
    return _token != null;
  }

  // ============= PURCHASE ORDER METHODS =============

  /// Get purchase order - requires po_no parameter
  Future<PurchaseOrderResponse> getPurchaseOrders({required String poNo}) async {
    try {
      final url = '$baseUrl/sap/purchase-orders?po_no=$poNo';

      print('🌐 Requesting PO: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      print('📡 Status: ${response.statusCode}');
      print('📡 Body: ${response.body}');

      final data = _handleResponse(response);
      return PurchaseOrderResponse.fromJson(data);
    } catch (e) {
      print('❌ Error: $e');
      rethrow;
    }
  }

  
 /// Create good receipt - Single item (simplified wrapper)
Future<GoodReceiptResponse> createGoodReceipt({
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
  // Just call createGoodReceiptBatch with single item
  return await createGoodReceiptBatch(
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

/// Create good receipt with multiple items - PRIMARY METHOD
Future<GoodReceiptResponse> createGoodReceiptBatch({
  required String dnNo,
  required String docDate,
  required String postDate,
  required List<GoodReceiptItem> items,
}) async {
  try {
    // Build items array matching Laravel controller validation
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
    print('📡 GR Response Body: ${response.body}');

    final data = _handleResponse(response);
    return GoodReceiptResponse.fromJson(data);
  } catch (e) {
    print('❌ GR Batch Error: $e');
    rethrow;
  }
}

  // ============= GR HISTORY METHODS (NEW) =============

  /// Get GR History for Timeline Dropdowns
  /// Returns all GR records grouped by item_po (line item)
  /// Used to populate DN No, Date GR, Batch No, and SLOC dropdowns
  Future<GrHistoryResponse> getGrHistory({required String poNo}) async {
    try {
      final url = '$baseUrl/sap/gr-history?po_no=$poNo';

      print('🌐 Requesting GR History: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      );

      print('📡 GR History Status: ${response.statusCode}');
      print('📡 GR History Body: ${response.body}');

      final data = _handleResponse(response);
      return GrHistoryResponse.fromJson(data);
    } catch (e) {
      print('❌ GR History Error: $e');
      rethrow;
    }
  }

  /// Optional: Get GR History for specific item only
  /// Useful if you want to load history only when user selects an item
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
      print('📡 GR History by Item Body: ${response.body}');

      final data = _handleResponse(response);
      return GrHistoryResponse.fromJson(data);
    } catch (e) {
      print('❌ GR History by Item Error: $e');
      rethrow;
    }
  }

  /// Optional: Get only unique dropdown values (lighter response)
  /// Returns distinct values for DN No, Date GR, Batch No, SLOC for a PO
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
      print('📡 GR Dropdown Values Body: ${response.body}');

      final data = _handleResponse(response);
      return GrDropdownValuesResponse.fromJson(data);
    } catch (e) {
      print('❌ GR Dropdown Values Error: $e');
      rethrow;
    }
  }
}