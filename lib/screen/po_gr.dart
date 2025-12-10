import 'package:flutter/material.dart';
import '/services/api_service.dart';
import '../main.dart';
import 'package:gr_po_oji/models/api_models.dart';
import '/services/holiday_service.dart';


class PoGrScreen extends StatefulWidget {
  const PoGrScreen({super.key});

  @override
  State<PoGrScreen> createState() => _PoGrScreenState();
}

class _PoGrScreenState extends State<PoGrScreen> {
  final SapApiService _apiService = SapApiService();
  
List<DateTime> _holidays = [];
  bool _holidaysLoaded = false;

  // Search
  final TextEditingController _poNoController = TextEditingController();

  bool _isPoLoading = false;
  bool _isGrLoading = false;

  final TextEditingController _rfidController = TextEditingController();
  final FocusNode _rfidFocusNode = FocusNode();
  bool _isRfidDialogOpen = false;
  
  // Search filters
  bool _showSearchFilters = false;
  final TextEditingController _itemNoSearchController = TextEditingController();
  final TextEditingController _materialCodeSearchController = TextEditingController();
  final TextEditingController _materialNameSearchController = TextEditingController();
  final TextEditingController _dnNoController = TextEditingController();
  final TextEditingController _batchNoController = TextEditingController();
  final TextEditingController _slocController = TextEditingController();
  
  bool _isItemFullyReceived(Map<String, dynamic> item) {
  final qtyPo = double.tryParse(item['QtyPO']?.toString() ?? '0') ?? 0;
  final qtyGrTotal = double.tryParse(item['QtyGRTotal']?.toString() ?? '0') ?? 0;
  return qtyGrTotal >= qtyPo;
}

// Add this method after _isItemFullyReceived
double _getQtyBalance(Map<String, dynamic> item) {
  final qtyPo = double.tryParse(item['QtyPO']?.toString() ?? '0') ?? 0;
  final qtyGrTotal = double.tryParse(item['QtyGRTotal']?.toString() ?? '0') ?? 0;
  final balance = qtyPo - qtyGrTotal;
  return balance > 0 ? balance : 0;
}

  UserProfile? _currentUser;

  // PO Data
  List<dynamic> _poItems = [];
  Map<String, dynamic>? _poHeader;
  bool _showPoDetails = false;
  
  // ✅ MULTI-SELECTION: Track selected items by ItemNo
  Set<String> _selectedItemNos = {};
  
  // ✅ MULTI-SELECTION: Store Qty GR per item (ItemNo -> TextEditingController)
  Map<String, TextEditingController> _qtyGrControllers = {};
  
  // GR History per item (keyed by ItemNo)
  Map<String, List<Map<String, dynamic>>> _grHistory = {};
  
  String _plant = '1200';

DateTime? _selectedPostDate;  
DateTime? _selectedDocDate;   

  
  // Filter text field widths
  static const double filterItemNoWidth = 60;
  static const double filterMaterialCodeWidth = 130;
  static const double filterMaterialNameWidth = 180;

  // ... rest of your code

  @override
  void initState() {
    super.initState();
    _initializeService();
    _loadHolidays();
  }

  Future<void> _initializeService() async {
    await _apiService.initialize();
    if (_apiService.isLoggedIn()) {
      try {
        final profile = await _apiService.getProfile();
        setState(() {
          _currentUser = profile;
        });
      } catch (e) {
        _showErrorSnackBar('Failed to load profile: $e');
      }
    }
  }

  Future<void> _loadHolidays() async {
  try {
    print('📥 Loading holidays from Nager.Date API...');
    
    // Fetch holidays for Indonesia (change 'ID' to your country code)
    final holidays = await HolidayService.prefetchHolidays('ID');
    
    setState(() {
      _holidays = holidays;
      _holidaysLoaded = true;
    });
    
    print('✅ Loaded ${_holidays.length} holidays for calendar');
  } catch (e) {
    print('⚠️ Failed to load holidays: $e');
    // Continue without holidays (weekends will still be blocked)
    setState(() {
      _holidaysLoaded = true; // Set to true to not block the UI
    });
  }
}

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  Future<void> _searchPO() async {
  if (_poNoController.text.isEmpty) {
    _showErrorSnackBar('Please enter PO number');
    return;
  }

  setState(() {
    _isPoLoading = true;
    _poItems = [];
    _poHeader = null;
    _showPoDetails = false;
    
    _grHistory = {};
    _resetSelections();
  });
  
  try {
    final response = await _apiService.getPurchaseOrders(
      poNo: _poNoController.text.trim(),
    );
    
    if (response.success) {
      if (response.data != null && response.data['value'] != null) {
        final items = response.data['value'] as List<dynamic>;
        if (items.isNotEmpty) {
          setState(() {
  _poItems = items;
  _poHeader = items.first;
  _showPoDetails = true;
  _isPoLoading = false;
  
  // ✅ Set default doc date from PO
  if (_poHeader!['DocDate'] != null) {
    try {
      _selectedDocDate = DateTime.parse(_poHeader!['DocDate'].toString());
    } catch (e) {
      _selectedDocDate = null;
    }
  }
});
          
          // ✨ LOAD REAL GR HISTORY FROM DATABASE
          await _loadGrHistory();
          
        } else {
          setState(() => _isPoLoading = false);
          _showErrorDialog('PO Not Released', 'This Purchase Order is not released yet.');
        }
      }
    } else {
      setState(() => _isPoLoading = false);
      _showErrorSnackBar(response.message ?? 'Failed to fetch PO');
    }
  } catch (e) {
    setState(() => _isPoLoading = false);
    _showErrorSnackBar(e.toString());
  }
}

  Future<void> _loadGrHistory() async {
  if (_poNoController.text.isEmpty) return;
  
  try {
    print('📥 Fetching GR history for PO: ${_poNoController.text.trim()}');
    
    final response = await _apiService.getGrHistory(
      poNo: _poNoController.text.trim(),
    );
    
    if (response.success && response.data != null) {
      print('✅ GR History loaded successfully');
      
      setState(() {
        _grHistory = {};
        
        // Convert GrHistoryResponse to Map<String, List<Map<String, dynamic>>>
        response.data!.forEach((itemNo, historyRecords) {
          _grHistory[itemNo] = historyRecords
              .map((record) => record.toMap())
              .toList();
        });
      });
      
      print('📊 GR History loaded for ${_grHistory.length} items');
      _grHistory.forEach((itemNo, history) {
        print('   Item $itemNo: ${history.length} GR records');
      });
      
      // Log metadata if available
      if (response.meta != null) {
        print('📈 Meta: ${response.meta!.itemsWithHistory} items, ${response.meta!.totalRecords} total records');
      }
      
    } else {
      print('⚠️ No GR history found: ${response.message}');
      setState(() {
        _grHistory = {};
      });
    }
  } catch (e) {
    print('❌ Failed to load GR history: $e');
    setState(() {
      _grHistory = {};
    });
    // Don't show error to user - empty history is acceptable
  }
}

  void _resetSelections() {
  _dnNoController.clear();
  _batchNoController.clear();
  _slocController.clear();
  _plant = '1200';
  
  // ✅ Clear all selected items
  _selectedItemNos.clear();
  
  // ✅ Dispose and clear all qty controllers
  _qtyGrControllers.forEach((key, controller) => controller.dispose());
  _qtyGrControllers.clear();
  
  // ✅ Reset dates
  _selectedPostDate = null;
  _selectedDocDate = null;
}

  void _toggleItemSelection(Map<String, dynamic> item) {
  final itemNo = item['ItemNo']?.toString() ?? '';
  
  setState(() {
    if (_selectedItemNos.contains(itemNo)) {
      // ✅ Deselect: Remove from set and dispose controller
      _selectedItemNos.remove(itemNo);
      _qtyGrControllers[itemNo]?.dispose();
      _qtyGrControllers.remove(itemNo);
    } else {
      // ✅ Select: Add to set and create new controller
      _selectedItemNos.add(itemNo);
      _qtyGrControllers[itemNo] = TextEditingController();
    }
    
    // Update plant from first selected item
    if (_selectedItemNos.isNotEmpty) {
      _plant = item['Plant']?.toString() ?? '1200';
    }
  });
}
/// Check if a date is a weekend (Saturday or Sunday)
bool _isWeekend(DateTime date) {
  return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
}

/// Check if a date is a public holiday (uses Nager.Date API data)
bool _isPublicHoliday(DateTime date) {
  if (!_holidaysLoaded || _holidays.isEmpty) {
    // If holidays not loaded yet or API failed, return false
    // (weekends will still be blocked)
    return false;
  }
  
  return _holidays.any((holiday) =>
      date.year == holiday.year &&
      date.month == holiday.month &&
      date.day == holiday.day);
}

/// Check if a date is selectable (not weekend, not public holiday)
bool _isSelectableDate(DateTime date) {
  return !_isWeekend(date) && !_isPublicHoliday(date);
}

/// Get the last working day of a month (skipping weekends and holidays)
DateTime _getLastWorkingDay(int year, int month) {
  // Start from last day of month
  DateTime lastDay = DateTime(year, month + 1, 0); // Last day of the month
  
  // Move backwards until we find a working day
  while (!_isSelectableDate(lastDay)) {
    lastDay = lastDay.subtract(const Duration(days: 1));
  }
  
  return lastDay;
}

/// Show date picker with custom rules
Future<void> _showDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required Function(DateTime) onDateSelected,
  required String helpText,
}) async {
  final picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    selectableDayPredicate: (DateTime date) {
      return _isSelectableDate(date);
    },
    // Force dd/MM/yyyy format
    locale: const Locale('en', 'GB'), // British English uses dd/MM/yyyy
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.blue[600]!,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      );
    },
  );

  if (picked != null) {
    onDateSelected(picked);
  }
}

/// Show Post Date picker with backdate rules
Future<void> _selectPostDate() async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  
  // Determine earliest selectable date based on backdate rules
  DateTime firstDate;
  
  if (now.day == 1) {
    // If today is 1st of month, can backdate to last working day of previous month
    firstDate = _getLastWorkingDay(now.year, now.month - 1);
  } else {
    // Can backdate freely within same month
    firstDate = DateTime(now.year, now.month, 1);
  }
  
  await _showDatePicker(
    context: context,
    initialDate: _selectedPostDate ?? today,
    firstDate: firstDate,
    lastDate: today,
    helpText: 'Select Post Date (Date GR)',
    onDateSelected: (picked) {
      setState(() {
        _selectedPostDate = picked;
      });
    },
  );
}

/// Show Doc Date picker with backdate rules (same as Post Date)
/// Show Doc Date picker with backdate rules (same as Post Date)
Future<void> _selectDocDate() async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  
  // Determine earliest selectable date based on backdate rules
  DateTime firstDate;
  
  if (now.day == 1) {
    // If today is 1st of month, can backdate to last working day of previous month
    firstDate = _getLastWorkingDay(now.year, now.month - 1);
  } else {
    // Can backdate freely within same month
    firstDate = DateTime(now.year, now.month, 1);
  }
  
  // Determine initial date (must be within selectable range)
  DateTime initialDate = today;
  
  if (_selectedDocDate != null) {
    // Use previously selected date if it's within range
    if (_selectedDocDate!.isAfter(firstDate) || _selectedDocDate!.isAtSameMomentAs(firstDate)) {
      initialDate = _selectedDocDate!;
    }
  } else if (_poHeader != null && _poHeader!['DocDate'] != null) {
    // Try to use PO doc date if it's within selectable range
    try {
      final poDate = DateTime.parse(_poHeader!['DocDate'].toString());
      if (poDate.isAfter(firstDate) || poDate.isAtSameMomentAs(firstDate)) {
        if (poDate.isBefore(today) || poDate.isAtSameMomentAs(today)) {
          initialDate = poDate;
        }
      }
    } catch (e) {
      // If parsing fails, use today
      initialDate = today;
    }
  }
  
  await _showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: today,
    helpText: 'Select Document Date',
    onDateSelected: (picked) {
      setState(() {
        _selectedDocDate = picked;
      });
    },
  );
}

/// Format date to DD-MM-YY
String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
}

  List<dynamic> _getFilteredPoItems() {
  if (!_showSearchFilters) return _poItems;
  
  return _poItems.where((item) {
    final itemNo = item['ItemNo']?.toString().toLowerCase() ?? '';
    final materialCode = item['MaterialCode']?.toString().toLowerCase() ?? '';
    final materialName = item['MaterialName']?.toString().toLowerCase() ?? '';
    
    final itemNoMatch = _itemNoSearchController.text.isEmpty || 
        itemNo.contains(_itemNoSearchController.text.toLowerCase());
    final materialCodeMatch = _materialCodeSearchController.text.isEmpty || 
        materialCode.contains(_materialCodeSearchController.text.toLowerCase());
    final materialNameMatch = _materialNameSearchController.text.isEmpty || 
        materialName.contains(_materialNameSearchController.text.toLowerCase());
    
    return itemNoMatch && materialCodeMatch && materialNameMatch;
  }).toList();
}

  Future<void> _createGoodReceiptFromHeader() async {
  // ✅ Validate: At least one item selected
  if (_selectedItemNos.isEmpty) {
    _showErrorSnackBar('Please select at least one item');
    return;
  }

  // ✅ Validate: Post Date is required
  if (_selectedPostDate == null) {
    _showErrorSnackBar('Please select Post Date (Date GR)');
    return;
  }

  // ✅ Validate: DN No is required
  String dnNo = _dnNoController.text.trim();
  if (dnNo.isEmpty) {
    _showErrorSnackBar('Please enter DN No');
    return;
  }

  // ✅ Validate: All selected items must have Qty GR
  List<String> missingQty = [];
  for (var itemNo in _selectedItemNos) {
    final qtyText = _qtyGrControllers[itemNo]?.text.trim() ?? '';
    if (qtyText.isEmpty) {
      missingQty.add(itemNo);
    }
  }

  if (missingQty.isNotEmpty) {
    _showErrorSnackBar('Please enter Qty GR for items: ${missingQty.join(", ")}');
    return;
  }

  // ✅ SHOW RFID VERIFICATION DIALOG
  await _showRfidVerificationDialog(dnNo);
}

/// Show RFID verification dialog before posting
Future<void> _showRfidVerificationDialog(String dnNo) async {
  _rfidController.clear();
  _isRfidDialogOpen = true;
  
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.tap_and_play,
                      color: Colors.blue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'RFID Verification Required',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _isRfidDialogOpen = false;
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.credit_card, color: Colors.blue[700], size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tap your RFID card to authorize posting',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _rfidController,
                focusNode: _rfidFocusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'RFID Card Number',
                  hintText: 'Scan or enter RFID card',
                  prefixIcon: const Icon(Icons.credit_card),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onSubmitted: (_) => _processGrWithRfid(dnNo),
              ),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _isRfidDialogOpen = false;
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isGrLoading ? null : () => _processGrWithRfid(dnNo),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isGrLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Verify & Post'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  ).then((_) {
    _isRfidDialogOpen = false;
  });
}

/// Process GR posting with RFID verification
Future<void> _processGrWithRfid(String dnNo) async {
  final rfidCard = _rfidController.text.trim();
  
  if (rfidCard.isEmpty) {
    _showErrorSnackBar('Please tap your RFID card');
    return;
  }

  String sloc = _slocController.text.trim();
  String batchNo = _batchNoController.text.trim();

  final docDate = _selectedDocDate != null 
      ? _formatDate(_selectedDocDate!)
      : (_poHeader!['DocDate']?.toString() ?? _formatDate(DateTime.now()));
      
  final postDate = _formatDate(_selectedPostDate!);

  setState(() => _isGrLoading = true);

  try {
    // ✅ Build items array for batch posting
    List<GoodReceiptItem> grItems = [];
    
    for (var itemNo in _selectedItemNos) {
      final itemData = _poItems.firstWhere(
        (item) => item['ItemNo']?.toString() == itemNo,
        orElse: () => null,
      );
      
      if (itemData == null) continue;
      
      final qtyGr = _qtyGrControllers[itemNo]?.text.trim() ?? '0';
      
      grItems.add(GoodReceiptItem(
        poNo: itemData['PoNo']?.toString() ?? '',
        itemPo: itemNo,
        qty: double.tryParse(qtyGr) ?? 0,
        plant: _plant,
        sloc: sloc.isNotEmpty ? sloc : null,
        batchNo: batchNo.isNotEmpty ? batchNo : null,
        dom: '',
      ));
    }

    print('🚀 Posting ${grItems.length} items to SAP with RFID: $rfidCard');
    print('📅 Doc Date: $docDate | Post Date: $postDate');

    // ✅ Call batch API with RFID
    final response = await _apiService.createGoodReceiptBatch(
      idCard: rfidCard,  // ✅ RFID verification
      dnNo: dnNo,
      docDate: docDate,
      postDate: postDate,
      items: grItems,
    );

    setState(() => _isGrLoading = false);

    // Close RFID dialog if successful
    if (_isRfidDialogOpen && mounted) {
      Navigator.of(context).pop();
    }

    if (response.success) {
      if (response.data != null) {
        final sapStatus = response.data['STATUS']?.toString().toUpperCase();
        
        if (sapStatus == 'ERROR') {
          _showErrorSnackBar('Error: ${response.data['MESSAGE']}');
        } else {
          final matDoc = response.data['MAT_DOC']?.toString() ?? 
                         response.data['mat_doc']?.toString() ?? '-';
          
          final postedData = {
            'po_no': _poHeader!['PoNo']?.toString() ?? '-',
            'items_count': grItems.length,
            'dn_no': dnNo,
            'doc_date': docDate,
            'post_date': postDate,
            'sloc': sloc.isNotEmpty ? sloc : null,
            'batch_no': batchNo.isNotEmpty ? batchNo : null,
            'items': grItems.map((item) => {
              'item_no': item.itemPo,
              'qty': item.qty.toString(),
            }).toList(),
          };
          
          // Clear inputs
          _dnNoController.clear();
          _batchNoController.clear();
          _slocController.clear();
          _rfidController.clear();
          _resetSelections();
          
          // Reload PO data
          await _searchPO();
          
          if (mounted) {
            _showGrSuccessDialog(matDoc, response.data, postedData);
          }
        }
      }
    } else {
      _showErrorSnackBar('API Error: ${response.message}');
    }
  } catch (e) {
    setState(() => _isGrLoading = false);
    
    // Handle RFID verification errors specifically
    if (e.toString().contains('RFID') || e.toString().contains('not registered')) {
      _showErrorSnackBar('Invalid RFID card. Please try again.');
      _rfidController.clear();
      _rfidFocusNode.requestFocus();
    } else {
      _showErrorSnackBar('Exception: $e');
    }
  }
}

void _showGrSuccessDialog(String matDoc, Map<String, dynamic>? responseData, Map<String, dynamic> postedData) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650), // ✅ Added maxHeight
          padding: const EdgeInsets.all(20), // ✅ Reduced padding from 24 to 20
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header - COMPACT
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6), // ✅ Reduced from 8
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 28, // ✅ Reduced from 32
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Good Receipt Created!',
                      style: TextStyle(
                        fontSize: 18, // ✅ Reduced from 20
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero, // ✅ Compact close button
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12), // ✅ Reduced from 20
              const Divider(height: 1),
              const SizedBox(height: 12), // ✅ Reduced from 16
              
              // ✅ SCROLLABLE CONTENT
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Material Document Number
                      Container(
                        padding: const EdgeInsets.all(12), // ✅ Reduced from 16
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Material Document',
                              style: TextStyle(
                                fontSize: 11, // ✅ Reduced from 12
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              matDoc,
                              style: const TextStyle(
                                fontSize: 22, // ✅ Reduced from 24
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Posted Details
                      Container(
                        padding: const EdgeInsets.all(12), // ✅ Reduced from 16
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Posted Details',
                              style: TextStyle(
                                fontSize: 13, // ✅ Reduced from 14
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildDetailRow('PO Number', postedData['po_no']),
                            _buildDetailRow('Items Posted', postedData['items_count'].toString()),
                            _buildDetailRow('DN No', postedData['dn_no']),
                            if (postedData['sloc'] != null)
                              _buildDetailRow('SLOC', postedData['sloc']),
                            if (postedData['batch_no'] != null)
                              _buildDetailRow('Batch No', postedData['batch_no']),
                            const SizedBox(height: 10),
                            const Text(
                              'Items:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            ...(postedData['items'] as List).map((item) => 
                              Padding(
                                padding: const EdgeInsets.only(left: 12, bottom: 3), // ✅ Reduced spacing
                                child: Text(
                                  '• Item ${item['item_no']}: Qty ${item['qty']}',
                                  style: const TextStyle(fontSize: 11), // ✅ Reduced from 12
                                ),
                              )
                            ).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Close button
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), // ✅ Reduced from 16
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 15, // ✅ Reduced from 16
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6), // ✅ Reduced from 8
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100, // ✅ Reduced from 120
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12, // ✅ Reduced from 13
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Text(': ', style: TextStyle(fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12, // ✅ Reduced from 13
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}


Widget _buildDataRow(Map<String, dynamic> item) {
  final itemNo = item['ItemNo']?.toString() ?? '';
  final isSelected = _selectedItemNos.contains(itemNo);
  final isFullyReceived = _isItemFullyReceived(item);
  final qtyBalance = _getQtyBalance(item);
  
  // Define consistent column widths
  const double itemNoWidth = 80;
  const double materialCodeWidth = 140;
  const double qtyPoWidth = 100;
  const double uomWidth = 80;
  const double qtyGrTotalWidth = 120;
  const double qtyBalanceWidth = 100;  // ✅ NEW
  const double goodReceiptWidth = 150;
  
  return InkWell(
    onTap: isFullyReceived ? null : () => _toggleItemSelection(item),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isFullyReceived 
            ? Colors.grey[100]  // ✅ Changed: Light grey for completed items
            : (isSelected ? Colors.blue[50] : Colors.white),
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: itemNoWidth, 
            child: Text(
              itemNo, 
              style: TextStyle(
                fontSize: 14,
                color: isFullyReceived ? Colors.grey[600] : Colors.black87,  // ✅ Lighter text for completed
                fontWeight: isFullyReceived ? FontWeight.normal : FontWeight.w500,
              ),
            )
          ),
          SizedBox(
            width: materialCodeWidth, 
            child: Text(
              item['MaterialCode']?.toString() ?? '-', 
              style: TextStyle(
                fontSize: 14,
                color: isFullyReceived ? Colors.grey[600] : Colors.black87,
              ),
            )
          ),
          Expanded(
            child: Text(
              item['MaterialName']?.toString() ?? '-',
              style: TextStyle(
                fontSize: 14,
                color: isFullyReceived ? Colors.grey[600] : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: qtyPoWidth,
            child: Text(
              item['QtyPO']?.toString() ?? '0',
              style: TextStyle(
                fontSize: 14,
                color: isFullyReceived ? Colors.grey[600] : Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          SizedBox(
            width: uomWidth,
            child: Text(
              item['UnitPO']?.toString() ?? '-',
              style: TextStyle(
                fontSize: 14,
                color: isFullyReceived ? Colors.grey[600] : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: qtyGrTotalWidth,
            child: Text(
              item['QtyGRTotal']?.toString() ?? '0',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isFullyReceived ? Colors.green[600] : Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // ✅ NEW: Qty Balance Column
          // ✅ NEW: Simple text like Qty PO, green if balance is 0
SizedBox(
  width: qtyBalanceWidth,
  child: Text(
    qtyBalance.toStringAsFixed(0),
    style: TextStyle(
      fontSize: 14,
      color: qtyBalance == 0 
          ? Colors.green[700]  // Green if fulfilled (balance = 0)
          : (isFullyReceived ? Colors.grey[600] : Colors.black87),
      fontWeight: qtyBalance == 0 ? FontWeight.bold : FontWeight.normal,
    ),
    textAlign: TextAlign.right,
  ),
),
          // ✅ Show Qty GR input ONLY if selected AND not fully received
          SizedBox(
            width: goodReceiptWidth,
            child: (isSelected && !isFullyReceived)
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      height: 32,
                      child: TextField(
                        controller: _qtyGrControllers[itemNo],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Enter Qty',
                          hintStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  )
                : isFullyReceived
                    ? Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                          size: 20,
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
          const SizedBox(width: 40), // Space for filter icon
        ],
      ),
    ),
  );
}


  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text('Purchase Order & Good Receipt'),
  backgroundColor: Colors.lightBlue,
  actions: [
    // Refresh Button (icon only)
    IconButton(
      icon: _isPoLoading 
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.refresh),
      onPressed: _isPoLoading ? null : () async {
        if (_poNoController.text.isNotEmpty) {
          await _searchPO();
        }
      },
      tooltip: 'Refresh PO Data',
    ),
    if (_currentUser != null) ...[
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle, size: 20),
                const SizedBox(width: 8),
                Text(_currentUser!.fullName, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () async {
          await _apiService.logout();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const SapLoginPage()),
              (route) => false,
            );
          }
        },
      ),
    ],
  ],
),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1024;
        
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSearchSection(isDesktop),
                
                if (_showPoDetails && _poHeader != null) ...[
                  const SizedBox(height: 24),
                  
                  
                  const SizedBox(height: 16),
                  _buildPoItemsTable(isDesktop),
                ],
                
                if (!_showPoDetails && !_isPoLoading) ...[
                  const SizedBox(height: 48),
                  _buildEmptyState(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchSection(bool isDesktop) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _poNoController,
                decoration: InputDecoration(
                  labelText: 'PO Number',
                  hintText: 'e.g., 4170005027',
                  prefixIcon: const Icon(Icons.numbers),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onSubmitted: (_) => _searchPO(),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: ElevatedButton.icon(
                onPressed: _isPoLoading ? null : _searchPO,
                icon: _isPoLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.search),
                label: Text(_isPoLoading ? 'Searching...' : 'Search'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


 Widget _buildPoItemsTable(bool isDesktop) {
  final filteredItems = _getFilteredPoItems();
  
  // Define consistent column widths
  const double itemNoWidth = 100;
  const double materialCodeWidth = 140; // Increased for 10 digits
  const double qtyPoWidth = 100;
  const double uomWidth = 80;
  const double qtyGrTotalWidth = 120;
  const double qtyBalanceWidth = 100;
  const double goodReceiptWidth = 150;
  
  
  return Card(
    elevation: 1,
    child: Column(
      children: [

        // PO Header Section
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.blue[50],
    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Column 1: PO No + PO Line Items
      Expanded(
        flex: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PO No', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text(
              _poHeader!['PoNo']?.toString() ?? '-',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
Text('PO Line Items (${_poItems.length})', 
  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              
          ],
        ),
      ),
      
      // Column 2: Supplier Name + Supplier Code
      Expanded(
        flex: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Supplier Name', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text(
              _poHeader!['SupplierName']?.toString() ?? '-',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 30),
            Text('Supplier Code', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text(
              _poHeader!['SupplierCode']?.toString() ?? '-',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      
      // Column 3: DN No + Date GR
Expanded(
  flex: 3,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('DN No', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      const SizedBox(height: 4),
      SizedBox(
        width: 160,
        height: 36,
        child: TextField(
          controller: _dnNoController,
          decoration: InputDecoration(
            hintText: 'Enter DN No',
            hintStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      const SizedBox(height: 12),
      
      // ✅ Post Date (Date GR) with Calendar Picker
      Text('Post Date (Date GR)', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      const SizedBox(height: 4),
      SizedBox(
        width: 140,
        height: 36,
        child: InkWell(
          onTap: _selectPostDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(6),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _selectedPostDate != null 
                        ? _formatDate(_selectedPostDate!)
                        : 'Select Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedPostDate != null ? Colors.black : Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  ),
),
      
      // Column 4: Batch No + SLOC
      Expanded(
        flex: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batch No', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            const SizedBox(height: 4),
            SizedBox(
              width: 160,
              height: 36,
              child: TextField(
  controller: _batchNoController,  // ✅ Use controller
  decoration: InputDecoration(
    hintText: 'Enter Batch No',
    hintStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
  ),
  style: const TextStyle(fontSize: 12),
),
            ),
            const SizedBox(height: 12),
            Text('SLOC', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
            const SizedBox(height: 4),
            SizedBox(
              width: 160,
              height: 36,
              child: TextField(
  controller: _slocController,  // ✅ Use controller
  decoration: InputDecoration(
    hintText: 'Enter SLOC',
    hintStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
  ), 
  style: const TextStyle(fontSize: 12),
),
            ),
          ],
        ),
      ),
      
      // Column 5: Plant + Doc Date
Expanded(
  flex: 2,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Plant', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      const SizedBox(height: 4),
      Text('1200', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 26),
      
      // ✅ Doc Date with Calendar Picker
Text('Doc Date', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
const SizedBox(height: 4),
SizedBox(
  width: 140,
  height: 36,
  child: InkWell(
    onTap: _selectDocDate,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _selectedDocDate != null 
                  ? _formatDate(_selectedDocDate!)
                  : (_poHeader!['DocDate']?.toString() ?? 'Select Date'),
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  ),
),
    ],
  ),
),
      
      // Column 6: Create GR Button
// Column 6: Create GR Button
Expanded(
  flex: 2,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Good Receipt', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
      const SizedBox(height: 4),
      SizedBox(
        width: 160,
        height: 36,
        child: ElevatedButton.icon(
          onPressed: (_isGrLoading || _selectedItemNos.isEmpty) ? null : _createGoodReceiptFromHeader,
          icon: _isGrLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.add_circle, size: 16),
          label: Text(
            _isGrLoading 
                ? 'Creating...' 
                : _selectedItemNos.isEmpty 
                    ? 'Select Items' 
                    : 'Create GR (${_selectedItemNos.length})',
            style: const TextStyle(fontSize: 11),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedItemNos.isEmpty ? Colors.grey : Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
    ],
  ),
),
    ],
  ),
),
        
        // Column Headers with Search Toggle
       // Inside _buildPoItemsTable, update the header row:

Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  color: Colors.grey[100],
  child: Row(
    children: [
      SizedBox(width: itemNoWidth, child: Text('Item No', style: _headerStyle())),
      SizedBox(width: materialCodeWidth, child: Text('Material Code', style: _headerStyle())),
      Expanded(child: Text('Material Name', style: _headerStyle())),
      SizedBox(width: qtyPoWidth, child: Text('Qty PO', style: _headerStyle(), textAlign: TextAlign.right)),
      SizedBox(width: uomWidth, child: Text('UoM', style: _headerStyle(), textAlign: TextAlign.center)),
      SizedBox(width: qtyGrTotalWidth, child: Text('Qty GR Total', style: _headerStyle(), textAlign: TextAlign.right)),
      SizedBox(width: qtyBalanceWidth, child: Text('Qty Balance', style: _headerStyle(), textAlign: TextAlign.right)),
      SizedBox(width: goodReceiptWidth, child: Text('Qty GR', style: _headerStyle(), textAlign: TextAlign.center)),
      SizedBox(
        width: 40,
        child: IconButton(
          icon: Icon(
            _showSearchFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
            size: 20,
            color: _showSearchFilters ? Colors.blue : Colors.grey[600],
          ),
          onPressed: () {
            setState(() {
              _showSearchFilters = !_showSearchFilters;
              if (!_showSearchFilters) {
                _itemNoSearchController.clear();
                _materialCodeSearchController.clear();
                _materialNameSearchController.clear();
              }
            });
          },
          tooltip: 'Toggle search filters',
        ),
      ),
    ],
  ),
),
        
        if (_showSearchFilters) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[50],
            child: Row(
              children: [
                // Item No Filter - SMALLER width
                SizedBox(
                  width: filterItemNoWidth,
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _itemNoSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 11),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Material Code Filter - SMALLER width
                SizedBox(
                  width: filterMaterialCodeWidth,
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _materialCodeSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 11),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Material Name Filter - SMALLER fixed width
                SizedBox(
                  width: filterMaterialNameWidth,
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      controller: _materialNameSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 11),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                // Spacer to push remaining content to the right
                const Spacer(),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        
        // Data Rows with Scroll (Max 5 visible)
        Container(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filteredItems.length,
            itemBuilder: (context, index) => _buildDataRow(filteredItems[index]),
          ),
        ),
        
        // Footer showing filtered count
        if (_showSearchFilters && filteredItems.length < _poItems.length)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.amber[50],
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.amber[800]),
                const SizedBox(width: 8),
                Text(
                  'Showing ${filteredItems.length} of ${_poItems.length} items',
                  style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}




  TextStyle _headerStyle() {
  return TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800]);
}

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No Purchase Order Found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        ],
      ),
    );
  }

  @override
void dispose() {
  _poNoController.dispose();
  _itemNoSearchController.dispose();
  _materialCodeSearchController.dispose();
  _materialNameSearchController.dispose();
  _dnNoController.dispose();
  _batchNoController.dispose();
  _slocController.dispose();
   _rfidController.dispose();  
  _rfidFocusNode.dispose();
  
  // ✅ Dispose all qty controllers
  _qtyGrControllers.forEach((key, controller) => controller.dispose());
  
  super.dispose();
}
}

// Simple Qty GR Dialog
class _QtyGrDialog extends StatefulWidget {
  final Map<String, dynamic> selectedItem;
  final Function(String, String, String) onSubmit;

  const _QtyGrDialog({
    required this.selectedItem,
    required this.onSubmit,
  });

  @override
  State<_QtyGrDialog> createState() => _QtyGrDialogState();
}

class _QtyGrDialogState extends State<_QtyGrDialog> {
  final TextEditingController _qtyGrController = TextEditingController();
  final TextEditingController _slocController = TextEditingController();
  final TextEditingController _batchController = TextEditingController();
  bool _isSubmitting = false;

  void _submit() async {
  if (_qtyGrController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Qty GR is required'), backgroundColor: Colors.red),
    );
    return;
  }

  setState(() => _isSubmitting = true);
  
  // Pass optional fields (can be empty strings)
  await widget.onSubmit(
    _qtyGrController.text.trim(),
    _slocController.text.trim(),
    _batchController.text.trim(),
  );
  
  setState(() => _isSubmitting = false);
}


  @override
Widget build(BuildContext context) {
  return Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 450),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Create Good Receipt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Item: ${widget.selectedItem['ItemNo']} - ${widget.selectedItem['MaterialName']}',
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const Divider(height: 24),
          
          // Qty GR (Mandatory)
          TextField(
            controller: _qtyGrController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Quantity GR *',
              hintText: 'Enter quantity to receive (required)',
              prefixIcon: const Icon(Icons.numbers),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          
          // SLOC (Optional)
          TextField(
            controller: _slocController,
            decoration: InputDecoration(
              labelText: 'SLOC (Optional)',
              hintText: 'Storage location (can be empty)',
              prefixIcon: const Icon(Icons.warehouse),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 16),
          
          // Batch No (Optional)
          TextField(
            controller: _batchController,
            decoration: InputDecoration(
              labelText: 'Batch No (Optional)',
              hintText: 'Batch number (can be empty)',
              prefixIcon: const Icon(Icons.qr_code),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
          const SizedBox(height: 24),
          
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check_circle),
            label: Text(_isSubmitting ? 'Creating GR...' : 'Create Good Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    ),
  );
}

  @override
void dispose() {
  _qtyGrController.dispose();
  _slocController.dispose();
  _batchController.dispose();
  super.dispose();
}
}