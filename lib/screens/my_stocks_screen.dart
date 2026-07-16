import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:searchable_dropdown/searchable_dropdown.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class MyStocksScreen extends StatefulWidget {
  const MyStocksScreen({super.key});

  @override
  State<MyStocksScreen> createState() => _MyStocksScreenState();
}

class _MyStocksScreenState extends State<MyStocksScreen> {
  List<dynamic> _stocks = [];
  List<dynamic> _models = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _errorMessage = '';
  int _currentPage = 1;
  int _lastPage = 1;
  
  // Form controllers
  final _formKey = GlobalKey<FormState>();
  String? _selectedModelId;
  final _capacityController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _colorController = TextEditingController();
  final _imei1Controller = TextEditingController();
  final _imei2Controller = TextEditingController();
  final _warrantyController = TextEditingController();
  
  bool _isCreating = false;
  bool _isEditing = false;
  String? _editingOrderId;
  
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _fetchStocks();
    _fetchModels();
    
    _timer = Timer.periodic(const Duration(seconds: 300), (timer) {
      _fetchStocks();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _capacityController.dispose();
    _buyPriceController.dispose();
    _colorController.dispose();
    _imei1Controller.dispose();
    _imei2Controller.dispose();
    _warrantyController.dispose();
    super.dispose();
  }

  Future<void> _fetchModels() async {
    try {
      final response = await ApiService.getModels();
      setState(() {
        _models = response;
      });
    } catch (e) {
      print('Error fetching models: $e');
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
    
    setState(() => _isCreating = true);

    try {
      final data = {
        'model_id': _selectedModelId,
        'capacity': _capacityController.text.trim(),
        'buy_price': double.parse(_buyPriceController.text.trim()),
        'color': _colorController.text.trim(),
        'imei_no_1': _imei1Controller.text.trim(),
        'imei_no_2': _imei2Controller.text.trim().isEmpty ? null : _imei2Controller.text.trim(),
        'warranty': _warrantyController.text.trim(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${response['message']}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => _isCreating = false);
  }

  Future<void> _editStock(dynamic stock) async {
    setState(() {
      _isEditing = true;
      _editingOrderId = stock['order_id'];
      _selectedModelId = stock['model_id'].toString();
      _capacityController.text = stock['capacity'] ?? '';
      _buyPriceController.text = stock['buy_price']?.toString() ?? '';
      _colorController.text = stock['color'] ?? '';
      _imei1Controller.text = stock['imei_no_1'] ?? '';
      _imei2Controller.text = stock['imei_no_2'] ?? '';
      _warrantyController.text = stock['warranty'] ?? '';
    });

    _showStockForm(isEdit: true);
  }

  Future<void> _updateStock() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isCreating = true);

    try {
      final data = {
        'order_id': _editingOrderId,
        'model_id': _selectedModelId,
        'capacity': _capacityController.text.trim(),
        'buy_price': double.parse(_buyPriceController.text.trim()),
        'color': _colorController.text.trim(),
        'imei_no_1': _imei1Controller.text.trim(),
        'imei_no_2': _imei2Controller.text.trim().isEmpty ? null : _imei2Controller.text.trim(),
        'warranty': _warrantyController.text.trim(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${response['message']}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }

    setState(() => _isCreating = false);
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
    _selectedModelId = null;
    _capacityController.clear();
    _buyPriceController.clear();
    _colorController.clear();
    _imei1Controller.clear();
    _imei2Controller.clear();
    _warrantyController.clear();
    _editingOrderId = null;
  }

  void _showStockForm({bool isEdit = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
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

                  // Searchable Model Dropdown (Select2-like)
                  SearchableDropdown.single(
                    value: _selectedModelId,
                    hint: 'Search for your model...',
                    searchHint: 'Type to search model...',
                    items: _models.map((model) {
                      return DropdownMenuItem<String>(
                        value: model['id'].toString(),
                        child: Text(
                          model['title'] ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedModelId = value as String?;
                      });
                    },
                    validator: (value) => value == null ? 'Please select a model' : null,
                    decoration: InputDecoration(
                      labelText: 'Model',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    dropdownStyle: DropdownStyle(
                      backgroundColor: const Color(0xFF2E2E3E),
                      borderRadius: BorderRadius.circular(12),
                      elevation: 4,
                      itemsHeight: 50,
                      itemsCount: _models.length > 10 ? 10 : _models.length,
                    ),
                    searchStyle: TextStyle(
                      color: Colors.white,
                      backgroundColor: const Color(0xFF1E1E2E),
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                    ),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    underline: Container(),
                    isExpanded: true,
                  ),
                  const SizedBox(height: 16),

                  // Capacity
                  TextFormField(
                    controller: _capacityController,
                    decoration: const InputDecoration(
                      labelText: 'Capacity (e.g., 256GB)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Enter capacity' : null,
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

                  // Warranty
                  TextFormField(
                    controller: _warrantyController,
                    decoration: const InputDecoration(
                      labelText: 'Warranty (e.g., 6 months)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Enter warranty' : null,
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : (isEdit ? _updateStock : _createStock),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                      ),
                      child: _isCreating
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