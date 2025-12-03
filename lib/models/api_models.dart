// ============= AUTHENTICATION MODELS =============

class LoginResponse {
  final bool success;
  final String message;
  final UserData userData;
  final String token;
  final String tokenType;

  LoginResponse({
    required this.success,
    required this.message,
    required this.userData,
    required this.token,
    required this.tokenType,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'],
      message: json['message'],
      userData: UserData.fromJson(json['data']['user']),
      token: json['data']['token'],
      tokenType: json['data']['token_type'],
    );
  }
}

class UserData {
  final String userId;
  final String fullName;
  final String firstName;
  final String lastName;
  final String jabatan;
  final String department;
  final String email;
  final String status;

  UserData({
    required this.userId,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.jabatan,
    required this.department,
    required this.email,
    required this.status,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      userId: json['user_id'] ?? '',
      fullName: json['full_name'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      jabatan: json['jabatan'] ?? '',
      department: json['department'] ?? '',
      email: json['email'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

class UserProfile {
  final String userId;
  final String fullName;
  final String firstName;
  final String lastName;
  final String jabatan;
  final String department;
  final String email;
  final String status;

  UserProfile({
    required this.userId,
    required this.fullName,
    required this.firstName,
    required this.lastName,
    required this.jabatan,
    required this.department,
    required this.email,
    required this.status,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] ?? '',
      fullName: json['full_name'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      jabatan: json['jabatan'] ?? '',
      department: json['department'] ?? '',
      email: json['email'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

// ============= PURCHASE ORDER MODELS =============

class PurchaseOrderResponse {
  final bool success;
  final String? message;
  final dynamic data;

  PurchaseOrderResponse({
    required this.success,
    this.message,
    required this.data,
  });

  factory PurchaseOrderResponse.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderResponse(
      success: json['success'],
      message: json['message'],
      data: json['data'],
    );
  }
}

// ============= GOOD RECEIPT MODELS =============

class GoodReceiptItem {
  final String poNo;
  final String itemPo;
  final double qty;
  final String plant;
  final String? sloc;
  final String? batchNo;
  final String? dom; // ✅ ADD THIS

  GoodReceiptItem({
    required this.poNo,
    required this.itemPo,
    required this.qty,
    required this.plant,
    this.sloc,
    this.batchNo,
    this.dom, // ✅ ADD THIS
  });

  Map<String, dynamic> toJson() => {
    'po_no': poNo,
    'item_po': itemPo,
    'qty': qty.toString(),
    'plant': plant,
    'sloc': sloc ?? '',
    'batch_no': batchNo ?? '',
    'dom': dom ?? '', // ✅ ADD THIS
  };

  factory GoodReceiptItem.fromJson(Map<String, dynamic> json) => GoodReceiptItem(
    poNo: json['po_no'] ?? '',
    itemPo: json['item_po'] ?? '',
    qty: double.tryParse(json['qty']?.toString() ?? '0') ?? 0,
    plant: json['plant'] ?? '',
    sloc: json['sloc'],
    batchNo: json['batch_no'],
    dom: json['dom'], // ✅ ADD THIS
  );
}

class GoodReceiptResponse {
  final bool success;
  final String message;
  final dynamic data;

  GoodReceiptResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory GoodReceiptResponse.fromJson(Map<String, dynamic> json) {
    return GoodReceiptResponse(
      success: json['success'],
      message: json['message'],
      data: json['data'],
    );
  }
}

// ============= GR HISTORY MODELS (NEW) =============

class GrHistoryResponse {
  final bool success;
  final String message;
  final Map<String, List<GrHistoryRecord>>? data;
  final GrHistoryMeta? meta;

  GrHistoryResponse({
    required this.success,
    required this.message,
    this.data,
    this.meta,
  });

  factory GrHistoryResponse.fromJson(Map<String, dynamic> json) {
    Map<String, List<GrHistoryRecord>>? parsedData;
    
    if (json['data'] != null) {
      parsedData = {};
      (json['data'] as Map<String, dynamic>).forEach((key, value) {
        if (value is List) {
          parsedData![key] = value
              .map((item) => GrHistoryRecord.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      });
    }

    return GrHistoryResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: parsedData,
      meta: json['meta'] != null ? GrHistoryMeta.fromJson(json['meta']) : null,
    );
  }
}

class GrHistoryRecord {
  final String dateGr;
  final String qty;
  final String dnNo;
  final String sloc;
  final String batchNo;
  final String matDoc;
  final String? docYear;
  final String? plant;
  final String? createdAt;
  final String? createdBy;
  final String? department;

  GrHistoryRecord({
    required this.dateGr,
    required this.qty,
    required this.dnNo,
    required this.sloc,
    required this.batchNo,
    required this.matDoc,
    this.docYear,
    this.plant,
    this.createdAt,
    this.createdBy,
    this.department,
  });

  factory GrHistoryRecord.fromJson(Map<String, dynamic> json) {
    return GrHistoryRecord(
      dateGr: json['date_gr'] ?? '',
      qty: json['qty']?.toString() ?? '0',
      dnNo: json['dn_no'] ?? '',
      sloc: json['sloc'] ?? '',
      batchNo: json['batch_no'] ?? '',
      matDoc: json['mat_doc'] ?? '',
      docYear: json['doc_year']?.toString(),
      plant: json['plant']?.toString(),
      createdAt: json['created_at'],
      createdBy: json['created_by'],
      department: json['department'],
    );
  }

  // Convert to Map for use in Flutter screens (backward compatible with old format)
  Map<String, dynamic> toMap() {
    return {
      'date_gr': dateGr,
      'qty': qty,
      'dn_no': dnNo,
      'sloc': sloc,
      'batch_no': batchNo,
      'mat_doc': matDoc,
      'doc_year': docYear,
      'plant': plant,
      'created_at': createdAt,
      'created_by': createdBy,
      'department': department,
    };
  }
}

class GrHistoryMeta {
  final String poNo;
  final int itemsWithHistory;
  final int totalRecords;

  GrHistoryMeta({
    required this.poNo,
    required this.itemsWithHistory,
    required this.totalRecords,
  });

  factory GrHistoryMeta.fromJson(Map<String, dynamic> json) {
    return GrHistoryMeta(
      poNo: json['po_no'] ?? '',
      itemsWithHistory: json['items_with_history'] ?? 0,
      totalRecords: json['total_records'] ?? 0,
    );
  }
}

// ============= GR DROPDOWN VALUES MODELS (NEW) =============

class GrDropdownValuesResponse {
  final bool success;
  final String message;
  final GrDropdownValues? data;
  final GrDropdownValuesMeta? meta;

  GrDropdownValuesResponse({
    required this.success,
    required this.message,
    this.data,
    this.meta,
  });

  factory GrDropdownValuesResponse.fromJson(Map<String, dynamic> json) {
    return GrDropdownValuesResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? GrDropdownValues.fromJson(json['data']) : null,
      meta: json['meta'] != null ? GrDropdownValuesMeta.fromJson(json['meta']) : null,
    );
  }
}

class GrDropdownValues {
  final List<String> dnNo;
  final List<String> dateGr;
  final List<String> batchNo;
  final List<String> sloc;

  GrDropdownValues({
    required this.dnNo,
    required this.dateGr,
    required this.batchNo,
    required this.sloc,
  });

  factory GrDropdownValues.fromJson(Map<String, dynamic> json) {
    return GrDropdownValues(
      dnNo: json['dn_no'] != null ? List<String>.from(json['dn_no']) : [],
      dateGr: json['date_gr'] != null ? List<String>.from(json['date_gr']) : [],
      batchNo: json['batch_no'] != null ? List<String>.from(json['batch_no']) : [],
      sloc: json['sloc'] != null ? List<String>.from(json['sloc']) : [],
    );
  }
}

class GrDropdownValuesMeta {
  final String poNo;
  final String? itemPo;
  final int totalRecords;

  GrDropdownValuesMeta({
    required this.poNo,
    this.itemPo,
    required this.totalRecords,
  });

  factory GrDropdownValuesMeta.fromJson(Map<String, dynamic> json) {
    return GrDropdownValuesMeta(
      poNo: json['po_no'] ?? '',
      itemPo: json['item_po'],
      totalRecords: json['total_records'] ?? 0,
    );
  }
}

// ============= EXCEPTION CLASS =============

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? errors;

  ApiException({
    required this.message,
    required this.statusCode,
    this.errors,
  });

  @override
  String toString() {
    if (errors != null) {
      return 'ApiException: $message (Status: $statusCode)\nErrors: $errors';
    }
    return 'ApiException: $message (Status: $statusCode)';
  }
}