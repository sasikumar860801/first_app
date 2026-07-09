import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class MPINScreen extends StatefulWidget {
  const MPINScreen({super.key});

  @override
  State<MPINScreen> createState() => _MPINScreenState();
}

class _MPINScreenState extends State<MPINScreen> {
  final TextEditingController _mpinController = TextEditingController();
  final TextEditingController _confirmMpinController = TextEditingController();
  bool _isLoading = false;
  bool _isVerifying = true;
  String _errorMessage = '';
  String _successMessage = '';

  @override
  void initState() {
    super.initState();
    _checkMpinStatus();
  }

  Future<void> _checkMpinStatus() async {
    // For demo, show verify option
    setState(() {
      _isVerifying = true;
    });
  }

  // ✅ NEW: Handle logout
  Future<void> _handleLogout() async {
    await ApiService.clearAll();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

 Future<void> _handleMpin() async {
  String mpin = _mpinController.text.trim();

  if (mpin.isEmpty) {
    setState(() {
      _errorMessage = 'Please enter MPIN';
      _successMessage = '';
    });
    return;
  }

  if (mpin.length != 4) {
    setState(() {
      _errorMessage = 'MPIN must be 4 digits';
      _successMessage = '';
    });
    return;
  }

  if (!_isVerifying) {
    String confirmMpin = _confirmMpinController.text.trim();
    if (mpin != confirmMpin) {
      setState(() {
        _errorMessage = 'MPIN does not match';
        _successMessage = '';
      });
      return;
    }
  }

  setState(() {
    _isLoading = true;
    _errorMessage = '';
    _successMessage = '';
  });

  try {
    dynamic response;
    
    if (_isVerifying) {
      response = await ApiService.verifyMpin(mpin);
    } else {
      response = await ApiService.updateMpin(mpin);
    }

    // ✅ CHECK: If unauthorized, clear and go to Login
    if (response['unauthorized'] == true) {
      await ApiService.clearAll();
      
      // Show message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Session expired. Please login again.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      
      // Navigate to Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
      return;
    }

    if (response['success'] == true) {
      if (_isVerifying) {
        // Navigate to Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DashboardScreen(),
          ),
        );
      } else {
        setState(() {
          _successMessage = 'MPIN set successfully!';
          _isVerifying = true;
          _mpinController.clear();
          _confirmMpinController.clear();
        });
      }
    } else {
      setState(() {
        _errorMessage = response['message'] ?? 'Operation failed';
      });
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Something went wrong';
    });
  }

  setState(() {
    _isLoading = false;
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isVerifying ? 'Verify MPIN' : 'Setup MPIN'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isVerifying ? Icons.lock_outline : Icons.lock_open,
              size: 80,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 20),
            Text(
              _isVerifying ? 'Enter your MPIN' : 'Create a new MPIN',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _isVerifying 
                  ? 'Please enter your 4-digit MPIN to continue' 
                  : 'Set a 4-digit MPIN for secure access',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            TextField(
              controller: _mpinController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                labelText: 'MPIN',
                hintText: 'Enter 4-digit MPIN',
                counterText: '',
                prefixIcon: Icon(Icons.lock),
              ),
            ),

            if (!_isVerifying) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _confirmMpinController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 4,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(
                  labelText: 'Confirm MPIN',
                  hintText: 'Re-enter 4-digit MPIN',
                  counterText: '',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],

            const SizedBox(height: 8),

            if (_successMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),

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
              onPressed: _isLoading ? null : _handleMpin,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isVerifying ? 'Verify MPIN' : 'Set MPIN',
                      style: const TextStyle(fontSize: 18),
                    ),
            ),

            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isVerifying = !_isVerifying;
                  _errorMessage = '';
                  _successMessage = '';
                  _mpinController.clear();
                  _confirmMpinController.clear();
                });
              },
              child: Text(
                _isVerifying 
                    ? 'Need to set new MPIN?' 
                    : 'Already have MPIN? Verify',
                style: const TextStyle(color: Colors.deepPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mpinController.dispose();
    _confirmMpinController.dispose();
    super.dispose();
  }
}