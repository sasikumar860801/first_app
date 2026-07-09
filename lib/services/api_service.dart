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

      final data = json.decode(response.body);
      
      if (data['success'] == true && data['auth_token'] != null) {
        await saveToken(data['auth_token']);
      }

      return data;
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> getDashboard() async {
    try {
      final token = await getToken();
      final dealerId = await getDealerId();

      final response = await http.post(
        Uri.parse('$baseUrl/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'dealer_id': dealerId}),
      );

      return json.decode(response.body);
    } catch (e) {
      return {'status': false, 'message': 'Network error: $e'};
    }
  }
}