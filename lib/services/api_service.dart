import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // This is working! (confirmed by your test)
  static const String baseUrl = 'http://127.0.0.1:8000/api';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }


  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> saveDealerId(int dealerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dealer_id', dealerId);
  }

  static Future<int?> getDealerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('dealer_id');
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

 static Future<bool> isLoggedIn() async {
    final token = await getToken();
    final dealerId = await getDealerId();
    return token != null && token.isNotEmpty && dealerId != null;
  }

  // Test method to verify API connection
  static Future<Map<String, dynamic>> testApi() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/test'),
      );
      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }

static Future<Map<String, dynamic>> getOtp(String phone) async {
  try {
 
    final response = await http.post(
      Uri.parse('$baseUrl/get-otp'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      return {
        'success': false, 
        'message': 'Server error: ${response.statusCode}'
      };
    }
  } catch (e) {
    return {'success': false, 'message': 'Network error: $e'};
  }
}
  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': phone,
          'otp': otp,
        }),
      );

      final data = json.decode(response.body);
      
      if (data['success'] == true) {
        await saveToken(data['auth_token']);
        await saveDealerId(data['dealer']['id']);
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateMpin(String mpin) async {
    try {
      final token = await getToken();
      final dealerId = await getDealerId();

      final response = await http.post(
        Uri.parse('$baseUrl/update-mpin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'dealer_id': dealerId,
          'mpin': mpin,
        }),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

 static Future<Map<String, dynamic>> verifyMpin(String mpin) async {
  try {
    final token = await getToken();
    final dealerId = await getDealerId();

    print('Verifying MPIN for dealer: $dealerId');

    final response = await http.post(
      Uri.parse('$baseUrl/verify-mpin'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'dealer_id': dealerId,
        'mpin': mpin,
      }),
    );

    print('MPIN Response Status: ${response.statusCode}');
    print('MPIN Response Body: ${response.body}');

    final data = json.decode(response.body);
    
    // ✅ CHECK: If unauthorized dealer or 401 status
    if (response.statusCode == 401 || 
        (data['success'] == false && data['message'] == 'Unauthorized dealer')) {
      print('⚠️ Unauthorized dealer - Clearing session');
      await clearAll();
      return {
        'success': false, 
        'message': data['message'] ?? 'Session expired',
        'unauthorized': true  // Flag to handle logout
      };
    }

    // ✅ Also check for other unauthorized messages
    if (data['success'] == false && 
        (data['message']?.contains('Unauthorized') ?? false)) {
      print('⚠️ Unauthorized - Clearing session');
      await clearAll();
      return {
        'success': false, 
        'message': data['message'] ?? 'Session expired',
        'unauthorized': true
      };
    }

    if (data['success'] == true && data['auth_token'] != null) {
      await saveToken(data['auth_token']);
    }

    return data;
  } catch (e) {
    print('Error in verifyMpin: $e');
    return {'success': false, 'message': 'Network error: $e'};
  }
}

 static Future<Map<String, dynamic>> getDashboard() async {
  try {
    final token = await getToken();
    final dealerId = await getDealerId();

    print('Getting dashboard for dealer: $dealerId');

    final response = await http.post(
      Uri.parse('$baseUrl/dashboard'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'dealer_id': dealerId}),
    );

    print('Dashboard Response Status: ${response.statusCode}');
    print('Dashboard Response Body: ${response.body}');

    final data = json.decode(response.body);
    
    // ✅ Check for unauthorized
    if (response.statusCode == 401 || response.statusCode == 403) {
      print('⚠️ Unauthorized - Clearing session');
      await clearAll();
      return {
        'status': false, 
        'message': data['message'] ?? 'Session expired',
        'unauthorized': true
      };
    }
    
    // ✅ Check for unauthorized dealer message
    if (data['status'] == false && 
        (data['message']?.contains('Unauthorized') ?? false)) {
      print('⚠️ Unauthorized dealer - Clearing session');
      await clearAll();
      return {
        'status': false, 
        'message': data['message'] ?? 'Session expired',
        'unauthorized': true
      };
    }

    return data;
  } catch (e) {
    print('Error in getDashboard: $e');
    return {'status': false, 'message': 'Network error: $e'};
  }
}

static Future<Map<String, dynamic>> getAccountBalanceHistory() async {
  try {
    final token = await getToken();
    final dealerId = await getDealerId();

    if (token == null || dealerId == null) {
      return {
        'status': false, 
        'message': 'User not authenticated'
      };
    }

    final response = await http.get(
      Uri.parse('$baseUrl/account-balance-history'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('Balance History Response: ${response.body}');
    
    if (response.statusCode == 401) {
      await clearAll();
      return {
        'status': false, 
        'message': 'Session expired',
        'unauthorized': true
      };
    }

    return json.decode(response.body);
  } catch (e) {
    return {'status': false, 'message': 'Network error: $e'};
  }
}

// Get New Leads
static Future<Map<String, dynamic>> getNewLeads() async {
  try {
    final token = await getToken();
    final dealerId = await getDealerId();

    if (token == null || dealerId == null) {
      return {
        'success': false, 
        'message': 'User not authenticated'
      };
    }

    final response = await http.get(
      Uri.parse('$baseUrl/new-leads?dealer_id=$dealerId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print('New Leads Response: ${response.body}');
    
    if (response.statusCode == 401) {
      await clearAll();
      return {
        'success': false, 
        'message': 'Session expired',
        'unauthorized': true
      };
    }

    return json.decode(response.body);
  } catch (e) {
    print('Error in getNewLeads: $e');
    return {'success': false, 'message': 'Network error: $e'};
  }
}

// Place Bid
static Future<Map<String, dynamic>> placeBid(String orderId, String percentage) async {
  try {
    final token = await getToken();
    final dealerId = await getDealerId();

    if (token == null || dealerId == null) {
      return {
        'success': false, 
        'message': 'User not authenticated'
      };
    }

    final response = await http.post(
      Uri.parse('$baseUrl/placeBid'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'dealer_id': dealerId,
        'order_id': orderId,
        'percentage': percentage,
      }),
    );

    print('Place Bid Response: ${response.body}');
    
    if (response.statusCode == 401) {
      await clearAll();
      return {
        'success': false, 
        'message': 'Session expired',
        'unauthorized': true
      };
    }

    return json.decode(response.body);
  } catch (e) {
    print('Error in placeBid: $e');
    return {'success': false, 'message': 'Network error: $e'};
  }
}

}