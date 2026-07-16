import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'transaction_history_screen.dart';
import 'new_leads_screen.dart';
import 'live_leads_screen.dart';
import 'history_leads_screen.dart';
import 'my_stocks_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _dashboardData = {};
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiService.getDashboard();
      
      if (response['unauthorized'] == true) {
        await ApiService.clearAll();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
        return;
      }

      if (response['status'] == true) {
        setState(() {
          _dashboardData = response['data'] ?? {};
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load dashboard';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await ApiService.clearAll();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_errorMessage),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchDashboard,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchDashboard,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Account Balance Card - Clickable
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TransactionHistoryScreen(),
                              ),
                            );
                          },
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Account Balance',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '₹${_dashboardData['account_balance']?.toString() ?? '0'}',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Tap to view transaction history',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Leads Grid
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                          GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const NewLeadsScreen(),
                                    ),
                                  );
                                },
                                child: _buildStatCard(
                                  'New Leads',
                                  _dashboardData['new_leads_count']?.toString() ?? '0',
                                  Icons.people_outline,
                                  Colors.blue,
                                ),
                              ),
                         GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LiveLeadsScreen(),
                                    ),
                                  );
                                },
                                child: _buildStatCard(
                                  'Live Leads',
                                  _dashboardData['live_leads_count']?.toString() ?? '0',
                                  Icons.sync,
                                  Colors.orange,
                                ),
                              ),

    GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HistoryLeadsScreen(initialTab: 0), // 0 = Completed
      ),
    );
  },
  child: _buildStatCard(
    'Completed Leads',
    _dashboardData['completed_leads_count']?.toString() ?? '0',
    Icons.check_circle_outline,
    Colors.green,
  ),
),

// Cancelled Leads Card - Clickable
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HistoryLeadsScreen(initialTab: 1), // 1 = Cancelled
      ),
    );
  },
  child: _buildStatCard(
    'Cancelled Leads',
    _dashboardData['cancelled_leads_count']?.toString() ?? '0',
    Icons.cancel_outlined,
    Colors.red,
  ),
),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stocks Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Stocks & Orders',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Divider(),
                               // My Stocks Card - Clickable
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MyStocksScreen(),
      ),
    );
  },
  child: _buildRowStat(
    'My Stocks',
    _dashboardData['my_stocks_count']?.toString() ?? '0',
    Icons.inventory,
  ),
),
                                _buildRowStat(
                                  'My Orders',
                                  _dashboardData['my_orders_count']?.toString() ?? '0',
                                  Icons.shopping_cart,
                                ),
                                _buildRowStat(
                                  'Completed Orders',
                                  _dashboardData['completed_my_orders_count']?.toString() ?? '0',
                                  Icons.done_all,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Services Section
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Services',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Divider(),
                                _buildRowStat(
                                  'New Service Requests',
                                  _dashboardData['new_service_repair_count']?.toString() ?? '0',
                                  Icons.build,
                                ),
                                _buildRowStat(
                                  'Completed Services',
                                  _dashboardData['completed_service_count']?.toString() ?? '0',
                                  Icons.verified,
                                ),
                                _buildRowStat(
                                  'Cancelled Services',
                                  _dashboardData['cancelled_service_count']?.toString() ?? '0',
                                  Icons.cancel,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowStat(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.deepPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}