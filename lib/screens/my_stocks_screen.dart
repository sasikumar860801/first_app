import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class MyStocksScreen extends StatefulWidget {
  const MyStocksScreen({super.key});

  @override
  State<MyStocksScreen> createState() => _MyStocksScreenState();
}

class _MyStocksScreenState extends State<MyStocksScreen> {
  List<dynamic> _stocks = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _errorMessage = '';
  int _currentPage = 1;
  int _lastPage = 1;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  
  // Model search
  String? _selectedModelId;
  String _selectedModelName = '';
  final TextEditingController _modelSearchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  
  // RAM and ROM
  final TextEditingController _ramController = TextEditingController();
  final TextEditingController _romController = TextEditingController();
  
  // Other fields
  final TextEditingController _buyPriceController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _imei1Controller = TextEditingController();
  final TextEditingController _imei2Controller = TextEditingController();
  String? _selectedWarranty;
  
  bool _isSubmitting = false;
  bool _isEditing = false;
  String? _editingOrderId;
  String _formError = '';
  
  late Timer _timer;

  final List<String> _warrantyOptions = [
    'No Warranty',
    '3 Months Warranty',
    '6 Months Warranty',
    '1 Year Warranty'
  ];

  @override
  void initState() {
    super.initState();
    _fetchStocks();
    
    _timer = Timer.periodic(const Duration(seconds: 300), (timer) {
      _fetchStocks();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _modelSearchController.dispose();
    _ramController.dispose();
    _romController.dispose();
    _buyPriceController.dispose();
    _colorController.dispose();
    _imei1Controller.dispose();
    _imei2Controller.dispose();
    super.dispose();
  }

 Future<void> _searchModel(String query) async {
  setState(() {
    _searchResults = [];
    if (query.isEmpty) {
      _selectedModelId = null;
      _selectedModelName = '';
      return;
    }
  });
  
  setState(() => _isSearching = true);
  
  try {
    final results = await ApiService.searchModel(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  } catch (e) {
    print('Search error: $e');
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }
}

  Future<void> _fetchStocks({bool loadMore = false}) async {
    if (loadMore) {
      if (_isLoadingMore || _currentPage >= _lastPage) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final response = await ApiService.listDealerStocks(page: _currentPage);

      if (response['unauthorized'] == true) {
        _timer.cancel();
        await ApiService.clearAll();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      if (response['status'] == 'success') {
        final data = response['data'];
        final items = data['data'] ?? [];
        _lastPage = data['last_page'] ?? 1;
        
        setState(() {
          if (loadMore) {
            _stocks.addAll(items);
          } else {
            _stocks = items;
          }
        });
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load stocks';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: $e';
      });
    }

    setState(() {
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  void _loadMore() {
    if (!_isLoadingMore && _currentPage < _lastPage) {
      _currentPage++;
      _fetchStocks(loadMore: true);
    }
  }

  Future<void> _createStock() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedModelId == null) {
      setState(() => _formError = 'Please search and select a model');
      return;
    }
    
    setState(() {
      _isSubmitting = true;
      _formError = '';
    });

    try {
      final data = {
        'model_id': _selectedModelId,
        'ram': int.parse(_ramController.text.trim()),
        'rom': int.parse(_romController.text.trim()),
        'buy_price': double.parse(_buyPriceController.text.trim()),
        'color': _colorController.text.trim(),
        'imei_no_1': _imei1Controller.text.trim(),
        'imei_no_2': _imei2Controller.text.trim().isEmpty ? null : _imei2Controller.text.trim(),
        'warranty': _selectedWarranty,
      };

      final response = await ApiService.createDealerStock(data);

      if (response['unauthorized'] == true) {
        _timer.cancel();
        await ApiService.clearAll();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Stock created successfully!'), backgroundColor: Colors.green),
        );
        _resetForm();
        _fetchStocks();
        Navigator.pop(context);
      } else {
        setState(() {
          _formError = response['message'] ?? 'Failed to create stock';
        });
      }
    } catch (e) {
      setState(() {
        _formError = 'Error: $e';
      });
    }

    setState(() => _isSubmitting = false);
  }

  Future<void> _editStock(dynamic stock) async {
    setState(() {
      _isEditing = true;
      _editingOrderId = stock['order_id'];
      _selectedModelId = stock['model_id'].toString();
      _selectedModelName = '${stock['brand_title'] ?? ''} ${stock['model_title'] ?? ''}';
      _modelSearchController.text = _selectedModelName;
      
      // Parse capacity to RAM/ROM
      String capacity = stock['capacity'] ?? '';
      if (capacity.contains('/')) {
        List<String> parts = capacity.split('/');
        if (parts.length == 2) {
          _ramController.text = parts[0].replaceAll('GB', '').trim();
          _romController.text = parts[1].replaceAll('GB', '').trim();
        }
      } else {
        _ramController.text = '';
        _romController.text = '';
      }
      
      _buyPriceController.text = stock['buy_price']?.toString() ?? '';
      _colorController.text = stock['color'] ?? '';
      _imei1Controller.text = stock['imei_no_1'] ?? '';
      _imei2Controller.text = stock['imei_no_2'] ?? '';
      _selectedWarranty = stock['warranty'] ?? '';
      _formError = '';
    });

    _showStockForm(isEdit: true);
  }

  Future<void> _updateStock() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedModelId == null) {
      setState(() => _formError = 'Please search and select a model');
      return;
    }
    
    setState(() {
      _isSubmitting = true;
      _formError = '';
    });

    try {
      final data = {
        'order_id': _editingOrderId,
        'model_id': _selectedModelId,
        'ram': int.parse(_ramController.text.trim()),
        'rom': int.parse(_romController.text.trim()),
        'buy_price': double.parse(_buyPriceController.text.trim()),
        'color': _colorController.text.trim(),
        'imei_no_1': _imei1Controller.text.trim(),
        'imei_no_2': _imei2Controller.text.trim().isEmpty ? null : _imei2Controller.text.trim(),
        'warranty': _selectedWarranty,
      };

      final response = await ApiService.editDealerStock(data);

      if (response['unauthorized'] == true) {
        _timer.cancel();
        await ApiService.clearAll();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Stock updated successfully!'), backgroundColor: Colors.green),
        );
        _resetForm();
        _fetchStocks();
        Navigator.pop(context);
      } else {
        setState(() {
          _formError = response['message'] ?? 'Failed to update stock';
        });
      }
    } catch (e) {
      setState(() {
        _formError = 'Error: $e';
      });
    }

    setState(() => _isSubmitting = false);
  }

  Future<void> _deleteStock(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Stock'),
        content: const Text('Are you sure you want to delete this stock?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await ApiService.deleteDealerStock(orderId);

      if (response['unauthorized'] == true) {
        _timer.cancel();
        await ApiService.clearAll();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        return;
      }

      if (response['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Stock deleted!'), backgroundColor: Colors.green),
        );
        _fetchStocks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${response['message']}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _selectedModelId = null;
      _selectedModelName = '';
      _modelSearchController.clear();
      _searchResults = [];
      _ramController.clear();
      _romController.clear();
      _buyPriceController.clear();
      _colorController.clear();
      _imei1Controller.clear();
      _imei2Controller.clear();
      _selectedWarranty = null;
      _editingOrderId = null;
      _isEditing = false;
      _formError = '';
    });
  }

  void _showStockForm({bool isEdit = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isEdit ? '✏️ Edit Stock' : '📦 Add New Stock',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Error Message
                  if (_formError.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formError,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _formError = ''),
                            child: const Icon(Icons.close, color: Colors.red, size: 18),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Model Search
                  TextFormField(
                    controller: _modelSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Search Model',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _searchModel,
                    validator: (value) {
                      if (_selectedModelId == null) {
                        return 'Please search and select a model';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Search Results
                  if (_isSearching)
                    const Center(child: CircularProgressIndicator())
                  else if (_searchResults.isNotEmpty && _modelSearchController.text.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade700),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length > 5 ? 5 : _searchResults.length,
                        itemBuilder: (context, index) {
                          final model = _searchResults[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              model['title'] ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedModelId = model['id'].toString();
                                _selectedModelName = model['title'] ?? '';
                                _modelSearchController.text = _selectedModelName;
                                _searchResults = [];
                              });
                            },
                          );
                        },
                      ),
                    ),

                  if (_selectedModelId != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selected: $_selectedModelName',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedModelId = null;
                                _selectedModelName = '';
                                _modelSearchController.clear();
                                _searchResults = [];
                              });
                            },
                            child: const Icon(Icons.close, size: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // RAM
                  TextFormField(
                    controller: _ramController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'RAM (GB)',
                      hintText: 'e.g., 8',
                      border: OutlineInputBorder(),
                      suffixText: 'GB',
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Enter RAM';
                      if (int.tryParse(value!) == null) return 'Enter valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // ROM
                  TextFormField(
                    controller: _romController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'ROM (GB)',
                      hintText: 'e.g., 128',
                      border: OutlineInputBorder(),
                      suffixText: 'GB',
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Enter ROM';
                      if (int.tryParse(value!) == null) return 'Enter valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Buy Price
                  TextFormField(
                    controller: _buyPriceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Buy Price (₹)',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Enter price';
                      if (double.tryParse(value!) == null) return 'Enter valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Color
                  TextFormField(
                    controller: _colorController,
                    decoration: const InputDecoration(
                      labelText: 'Color',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Enter color' : null,
                  ),
                  const SizedBox(height: 12),

                  // IMEI 1
                  TextFormField(
                    controller: _imei1Controller,
                    decoration: const InputDecoration(
                      labelText: 'IMEI Number 1',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Enter IMEI number' : null,
                  ),
                  const SizedBox(height: 12),

                  // IMEI 2
                  TextFormField(
                    controller: _imei2Controller,
                    decoration: const InputDecoration(
                      labelText: 'IMEI Number 2 (Optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Warranty Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedWarranty,
                    hint: const Text('Select Warranty', style: TextStyle(color: Colors.grey)),
                    isExpanded: true,
                    items: _warrantyOptions.map((option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedWarranty = value;
                      });
                    },
                    validator: (value) => value == null ? 'Please select warranty' : null,
                    decoration: const InputDecoration(
                      labelText: 'Warranty',
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: const Color(0xFF2E2E3E),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : (isEdit ? _updateStock : _createStock),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(isEdit ? '✏️ Update Stock' : '📦 Add Stock'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(_resetForm);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Stocks'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStocks,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showStockForm(),
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
                        onPressed: _fetchStocks,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _stocks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory, size: 80, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('No stocks added yet'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _showStockForm(),
                            child: const Text('Add Stock'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _stocks.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _stocks.length) {
                          if (_currentPage < _lastPage) {
                            _loadMore();
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return const SizedBox.shrink();
                        }

                        final stock = _stocks[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${stock['brand_title'] ?? ''} ${stock['model_title'] ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '📦 ${stock['capacity'] ?? ''}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          Text(
                                            '🎨 ${stock['color'] ?? ''}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                '₹${stock['buy_price'] ?? 0}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: stock['is_approved'] == 1
                                                      ? Colors.green.withOpacity(0.2)
                                                      : Colors.orange.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  stock['is_approved'] == 1
                                                      ? '✅ Approved'
                                                      : '⏳ Pending',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: stock['is_approved'] == 1
                                                        ? Colors.green
                                                        : Colors.orange,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '📱 IMEI: ${stock['imei_no_1'] ?? ''}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _editStock(stock),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.blue,
                                          minimumSize: const Size(double.infinity, 36),
                                        ),
                                        icon: const Icon(Icons.edit, size: 16),
                                        label: const Text('Edit'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _deleteStock(stock['order_id']),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          minimumSize: const Size(double.infinity, 36),
                                        ),
                                        icon: const Icon(Icons.delete, size: 16),
                                        label: const Text('Delete'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}