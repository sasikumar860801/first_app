import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'package:flutter/services.dart';

class NewLeadsScreen extends StatefulWidget {
  const NewLeadsScreen({super.key});

  @override
  State<NewLeadsScreen> createState() => _NewLeadsScreenState();
}

class _NewLeadsScreenState extends State<NewLeadsScreen> {
  List<dynamic> _leads = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _bidOrderId = '';
  String _bidPercentage = '';
  bool _isBidding = false;
  Set<String> _expandedOrders = {}; // Track expanded Q&A

  @override
  void initState() {
    super.initState();
    _fetchLeads();
  }

  Future<void> _fetchLeads() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ApiService.getNewLeads();

      if (response['unauthorized'] == true) {
        await ApiService.clearAll();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      if (response['success'] == true) {
        setState(() {
          _leads = response['data'] ?? [];
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load leads';
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

  Future<void> _placeBid(String orderId) async {
    if (_bidPercentage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter bid percentage'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    double? percentage = double.tryParse(_bidPercentage);
    if (percentage == null || percentage <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid percentage'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ Restrict max 20%
    if (percentage > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Bid percentage cannot exceed 20%'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isBidding = true;
    });

    try {
      final response = await ApiService.placeBid(orderId, _bidPercentage);

      if (response['unauthorized'] == true) {
        await ApiService.clearAll();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Bid placed! Commission: ₹${(response['data']['commission'] as num?)?.toStringAsFixed(0) ?? '0'}'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchLeads();
        setState(() {
          _bidOrderId = '';
          _bidPercentage = '';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${response['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isBidding = false;
    });
  }

  Future<int> _getDealerId() async {
    int? id = await ApiService.getDealerId();
    return id ?? 1;
  }

  Color _getBidColor(Map<String, dynamic>? bidding, int dealerId) {
    if (bidding == null || bidding.isEmpty) {
      return Colors.grey;
    }

    String dealerIdStr = dealerId.toString();
    
    if (bidding.containsKey(dealerIdStr)) {
      String color = bidding[dealerIdStr]['color'] ?? '';
      if (color == 'green') return Colors.green;
      if (color == 'red') return Colors.red;
    }

    if (bidding.isNotEmpty) {
      return Colors.red;
    }

    return Colors.grey;
  }

  String _getBidStatus(Map<String, dynamic>? bidding, int dealerId) {
    if (bidding == null || bidding.isEmpty) {
      return '⚪ No Bid';
    }

    String dealerIdStr = dealerId.toString();
    
    if (bidding.containsKey(dealerIdStr)) {
      String color = bidding[dealerIdStr]['color'] ?? '';
      // ✅ Fix: Convert percent to double safely
      double percent = 0;
      var percentValue = bidding[dealerIdStr]['percent'];
      if (percentValue is int) {
        percent = percentValue.toDouble();
      } else if (percentValue is double) {
        percent = percentValue;
      } else if (percentValue is String) {
        percent = double.tryParse(percentValue) ?? 0;
      }
      
      if (color == 'green') {
        return '🟢 Highest (${percent.toStringAsFixed(0)}%)';
      }
      if (color == 'red') {
        return '🔴 Outbid (${percent.toStringAsFixed(0)}%)';
      }
    }

    return '🔴 Bid Placed';
  }

  // ✅ Fix: Get highest bid safely
String _getHighestBid(Map<String, dynamic>? bidding) {
  if (bidding == null || bidding.isEmpty) {
    return 'No bid';
  }

  double highest = 0.0;

  bidding.forEach((key, value) {
    if (value is Map) {
      var p = value['percent'];
      double percent = 0.0;
      if (p is int) percent = p.toDouble();
      else if (p is double) percent = p;
      else if (p is String) percent = double.tryParse(p) ?? 0.0;

      if (percent > highest) highest = percent;
    }
  });

  return '${highest.toStringAsFixed(0)}%';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Leads'),
        backgroundColor: const Color(0xFF1E1E1E),
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
              : _leads.isEmpty
                  ? const Center(
                      child: Text('No new leads available'),
                    )
                  : FutureBuilder<int>(
                      future: _getDealerId(),
                      builder: (context, snapshot) {
                        int dealerId = snapshot.data ?? 1;
                        
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _leads.length,
                          itemBuilder: (context, index) {
                            final lead = _leads[index];
                            final bidding = lead['bidding'] as Map<String, dynamic>?;
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
                                            color: _getBidColor(bidding, dealerId),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _getBidStatus(bidding, dealerId),
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
                                    const SizedBox(height: 12),

                                    // Location and Date
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${lead['area_name'] ?? 'N/A'}, ${lead['pincode'] ?? ''}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ),
                                        const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          lead['shipping_pickup_date'] ?? 'N/A',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Capacity and Highest Bid
                                    Row(
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
                                        const SizedBox(width: 8),
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
                                            '🏷️ Highest: ${_getHighestBid(bidding)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // ✅ NEW: Device Condition Button with Expand/Collapse
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
                                    const SizedBox(height: 12),

                                    // Bid Section
                                    if (_bidOrderId == lead['order_id']) ...[
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                              inputFormatters: [
                                                FilteringTextInputFormatter.digitsOnly,
                                              ],
                                              decoration: const InputDecoration(
                                                labelText: 'Bid % (1-20)',
                                                hintText: 'Enter percentage',
                                                border: OutlineInputBorder(),
                                                contentPadding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                                suffixText: '%',
                                              ),
                                              onChanged: (value) {
                                                setState(() {
                                                  _bidPercentage = value;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: _isBidding ? null : () => _placeBid(lead['order_id']),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.deepPurple,
                                              minimumSize: const Size(80, 45),
                                            ),
                                            child: _isBidding
                                                ? const SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Text('Bid'),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () {
                                              setState(() {
                                                _bidOrderId = '';
                                                _bidPercentage = '';
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        '⚠️ Enter whole number only (1-20)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ] else ...[
                                      ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _bidOrderId = lead['order_id'];
                                            _bidPercentage = '';
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepPurple,
                                          minimumSize: const Size(double.infinity, 40),
                                        ),
                                        child: const Text('Bid Now'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
    );
  }
}