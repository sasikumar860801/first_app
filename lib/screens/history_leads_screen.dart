import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class HistoryLeadsScreen extends StatefulWidget {
  final int initialTab;
  
  const HistoryLeadsScreen({super.key, this.initialTab = 0});

  @override
  State<HistoryLeadsScreen> createState() => _HistoryLeadsScreenState();
}

class _HistoryLeadsScreenState extends State<HistoryLeadsScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _completedLeads = [];
  List<dynamic> _cancelledLeads = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Set<String> _expandedOrders = {};
  
  late TabController _tabController;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _fetchLeads();
    
    // Refresh every 5 minutes
    _timer = Timer.periodic(const Duration(seconds: 300), (timer) {
      _fetchLeads();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _timer.cancel();
    super.dispose();
  }

  Future<void> _fetchLeads() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiService.getHistoryLeads();

      if (response['unauthorized'] == true) {
        _timer.cancel();
        await ApiService.clearAll();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      if (response['success'] == true) {
        final data = response['data'] ?? [];
        
        // Split into completed and cancelled
        setState(() {
          _completedLeads = data.where((lead) => lead['status'] == 'completed').toList();
          _cancelledLeads = data.where((lead) => lead['status'] == 'cancelled').toList();
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load history';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _toggleExpand(String orderId) {
    setState(() {
      if (_expandedOrders.contains(orderId)) {
        _expandedOrders.remove(orderId);
      } else {
        _expandedOrders.add(orderId);
      }
    });
  }

  Widget _buildHistoryCard(dynamic lead, String type) {
    final orderId = lead['order_id'] ?? '';
    bool isExpanded = _expandedOrders.contains(orderId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '#${lead['order_id'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: type == 'completed' ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    type == 'completed' ? '✅ Completed' : '❌ Cancelled',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Model Image and Name
            Row(
              children: [
                if (lead['model_img'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      lead['model_img'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey.shade800,
                          child: const Icon(
                            Icons.phone_android,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead['model_name'] ?? 'Unknown Model',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '₹${(lead['price'] as num?)?.toStringAsFixed(0) ?? '0'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Customer Info
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        lead['customer_name'] ?? 'N/A',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        lead['mobile_no'] ?? 'N/A',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  if (lead['alternate_mob_no'] != null && lead['alternate_mob_no'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.phone_android, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Alt: ${lead['alternate_mob_no']}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Location
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📍 ${lead['address'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (lead['landmark'] != null && lead['landmark'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '🏷️ ${lead['landmark']}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '📍 ${lead['area_name'] ?? 'N/A'}, ${lead['pincode'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Capacity and Pickup
            Wrap(
              spacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '📦 ${lead['capacity'] ?? 'N/A'}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '📅 ${lead['shipping_pickup_date'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.blue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '🕐 ${lead['shipping_pickup_time'] ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Device Condition Button
            if ((lead['qa'] != null && lead['qa'].isNotEmpty) ||
                (lead['reported_issues'] != null && lead['reported_issues'].isNotEmpty))
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _toggleExpand(orderId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExpanded 
                          ? Colors.red.shade900 
                          : Colors.blue.shade900,
                      minimumSize: const Size(double.infinity, 36),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: Icon(
                      isExpanded 
                          ? Icons.visibility_off 
                          : Icons.visibility,
                      size: 16,
                    ),
                    label: Text(
                      isExpanded 
                          ? 'Hide Device Condition' 
                          : 'Show Device Condition',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    
                    // Q&A Section
                    if (lead['qa'] != null && lead['qa'].isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '📋 Q&A:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ...lead['qa'].map<Widget>((qa) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontSize: 12)),
                                    Expanded(
                                      child: Text(
                                        '${qa['question']} - ${qa['answer']}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    
                    // Reported Issues
                    if (lead['reported_issues'] != null && lead['reported_issues'].isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '⚠️ Reported Issues:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            Wrap(
                              spacing: 4,
                              children: lead['reported_issues'].map<Widget>((issue) {
                                return Chip(
                                  label: Text(
                                    issue,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.red.shade900.withOpacity(0.3),
                                  padding: const EdgeInsets.all(0),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History Leads'),
        backgroundColor: const Color(0xFF1E1E1E),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '✅ Completed'),
            Tab(text: '❌ Cancelled'),
          ],
          indicatorColor: Colors.deepPurple,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLeads,
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
                        onPressed: _fetchLeads,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Completed Tab
                    _completedLeads.isEmpty
                        ? const Center(child: Text('No completed leads'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _completedLeads.length,
                            itemBuilder: (context, index) {
                              return _buildHistoryCard(_completedLeads[index], 'completed');
                            },
                          ),
                    // Cancelled Tab
                    _cancelledLeads.isEmpty
                        ? const Center(child: Text('No cancelled leads'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _cancelledLeads.length,
                            itemBuilder: (context, index) {
                              return _buildHistoryCard(_cancelledLeads[index], 'cancelled');
                            },
                          ),
                  ],
                ),
    );
  }
}