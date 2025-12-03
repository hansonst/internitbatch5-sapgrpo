import 'package:http/http.dart' as http;
import 'dart:convert';

class HolidayService {
  static const String _baseUrl = 'https://date.nager.at/api/v3';
  static final Map<String, List<DateTime>> _holidayCache = {};
  
  /// Fetch holidays for Indonesia (ID)
  static Future<List<DateTime>> fetchIndonesiaHolidays(int year) async {
    return fetchHolidays(year, 'ID');
  }
  
  /// Fetch holidays for any country
  /// Country codes: ID (Indonesia), US (United States), GB (United Kingdom), etc.
  static Future<List<DateTime>> fetchHolidays(int year, String countryCode) async {
    final cacheKey = '$countryCode-$year';
    
    // Return cached data if available
    if (_holidayCache.containsKey(cacheKey)) {
      print('✅ Using cached holidays for $countryCode $year');
      return _holidayCache[cacheKey]!;
    }
    
    try {
      print('🌐 Fetching holidays from API: $countryCode $year');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/PublicHolidays/$year/$countryCode'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final holidays = <DateTime>[];
        
        for (var holiday in data) {
          final dateStr = holiday['date'];
          final date = DateTime.parse(dateStr);
          holidays.add(DateTime(date.year, date.month, date.day));
          
          // Debug: Print holiday names
          print('  📅 ${holiday['localName']} - $dateStr');
        }
        
        // Cache the results
        _holidayCache[cacheKey] = holidays;
        print('✅ Loaded ${holidays.length} holidays for $countryCode $year');
        return holidays;
      } else {
        print('⚠️ Failed to fetch holidays: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching holidays: $e');
    }
    
    // Return empty list on error (fallback to weekends only)
    return [];
  }
  
  /// Prefetch holidays for current and next year
  static Future<List<DateTime>> prefetchHolidays(String countryCode) async {
    final now = DateTime.now();
    final currentYear = now.year;
    
    // Fetch both years in parallel
    final results = await Future.wait([
      fetchHolidays(currentYear, countryCode),
      fetchHolidays(currentYear + 1, countryCode),
    ]);
    
    return [...results[0], ...results[1]];
  }
  
  /// Clear cache (useful for manual refresh)
  static void clearCache() {
    _holidayCache.clear();
    print('🗑️ Holiday cache cleared');
  }
}