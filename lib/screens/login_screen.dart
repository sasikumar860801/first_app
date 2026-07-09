import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _testGetOtpApi();
  }

  // TEST THE ACTUAL get-otp API
  Future<void> _testGetOtpApi() async {
    setState(() {
      _debugInfo = 'Testing API connection...';
    });

    try {
      // Use a test phone number
      String testPhone = '8608015673';
      
      print('📱 Testing get-otp API with phone: $testPhone');
      
      final response = await ApiService.getOtp(testPhone);
      
      print('📥 Response: $response');
      
      setState(() {
        if (response['success'] == true) {
          _debugInfo = '✅ API Working! OTP: ${response['otp']}';
          _showSnackBar('✅ API Working! OTP: ${response['otp']}', Colors.green);
        } else {
          _debugInfo = '❌ API Error: ${response['message']}';
          _showSnackBar('❌ Error: ${response['message']}', Colors.red);
        }
      });
    } catch (e) {
      print('❌ Exception: $e');
      setState(() {
        _debugInfo = '❌ Connection Error: $e';
        _showSnackBar('❌ Connection Error: $e', Colors.red);
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _getOtp() async {
    String phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter phone number';
      });
      return;
    }

    if (phone.length != 10) {
      setState(() {
        _errorMessage = 'Please enter valid 10-digit phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _debugInfo = '';
    });

    try {
      print('📱 Sending OTP request for: $phone');
      
      final response = await ApiService.getOtp(phone);
      
      print('📥 Response: $response');

      if (response['success'] == true) {
        // Show OTP in snackbar for testing
        _showSnackBar('✅ OTP: ${response['otp']}', Colors.blue);
        
        // Navigate to OTP screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(phone: phone),
          ),
        );
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to send OTP';
        });
        _showSnackBar(_errorMessage, Colors.red);
      }
    } catch (e) {
      print('❌ Exception: $e');
      setState(() {
        _errorMessage = 'Network error: $e';
      });
      _showSnackBar('Network error: $e', Colors.red);
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ FIXED: Container with proper closing
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.storefront,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 40),
            
            const Text(
              'Welcome Dealer!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your mobile number to continue',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            
            // Debug Info
            if (_debugInfo.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _debugInfo.contains('✅') 
                      ? Colors.green.withOpacity(0.1) 
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _debugInfo.contains('✅') 
                        ? Colors.green 
                        : Colors.orange,
                  ),
                ),
                child: Text(
                  _debugInfo,
                  style: TextStyle(
                    color: _debugInfo.contains('✅') 
                        ? Colors.green 
                        : Colors.orange,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            
            const SizedBox(height: 40),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                hintText: 'Enter 10-digit number',
                prefixIcon: Icon(Icons.phone_android),
                counterText: '',
              ),
            ),

            const SizedBox(height: 8),

            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isLoading ? null : _getOtp,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Get OTP',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Button
            ElevatedButton(
              onPressed: _isLoading ? null : _testGetOtpApi,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                minimumSize: const Size(double.infinity, 40),
              ),
              child: const Text(
                '🔄 Test API Again',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}