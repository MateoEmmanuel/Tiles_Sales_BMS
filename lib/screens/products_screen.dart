import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import 'connection_status_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _firebaseService = FirebaseService();
  final _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _products =>
      _firebaseService.getFirestore().collection('products');

  Future<void> _openProductForm([
    DocumentSnapshot<Map<String, dynamic>>? product,
  ]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductFormScreen(product: product),
      ),
    );
  }

  Future<void> _deleteProduct(
    DocumentSnapshot<Map<String, dynamic>> product,
  ) async {
    final data = product.data() ?? {};
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text(
          'This will permanently delete ${data['productName'] ?? 'this product'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await _products.doc(product.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product deleted')));
      }
    } catch (error) {
      _showError('Could not delete product: $error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showProduct(DocumentSnapshot<Map<String, dynamic>> product) {
    final data = product.data() ?? {};
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['productName']?.toString() ?? 'Product details'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              children: _productFields(data).entries
                  .map(
                    (entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Text(entry.value, textAlign: TextAlign.right),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _openProductForm(product);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Map<String, String> _productFields(Map<String, dynamic> data) => {
    'Product code': '${data['productCode'] ?? '-'}',
    'Brand': '${data['brand'] ?? '-'}',
    'Design': '${data['design'] ?? '-'}',
    'Color': '${data['color'] ?? '-'}',
    'Size': '${data['size'] ?? '-'}',
    'Thickness': '${data['thickness'] ?? '-'} mm',
    'Finish': '${data['finish'] ?? '-'}',
    'Pieces per box': '${data['piecesPerBox'] ?? '-'}',
    'Coverage per box': '${data['coveragePerBox'] ?? '-'} sqm',
    'Price per box': '₱${data['pricePerBox'] ?? '-'}',
    'Price per sqm': '₱${data['pricePerSqm'] ?? '-'}',
    'Price per sqft': '₱${data['pricePerSqft'] ?? '-'}',
    'Reorder point': '${data['reorderPoint'] ?? '-'}',
    'Status': '${data['status'] ?? '-'}',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Connection status',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ConnectionStatusScreen(),
              ),
            ),
            icon: const Icon(Icons.cloud_done_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _searchTerm = value.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by code, name, brand, or design',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchTerm.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchTerm = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: !_firebaseService.isInitialized
                ? const Center(child: Text('Firebase is not initialized'))
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _products.orderBy('productName').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Could not load products.\n${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final products = snapshot.data!.docs.where((product) {
                        final data = product.data();
                        final searchable = [
                          data['productCode'],
                          data['productName'],
                          data['brand'],
                          data['design'],
                        ].join(' ').toLowerCase();
                        return searchable.contains(_searchTerm);
                      }).toList();
                      if (products.isEmpty) {
                        return Center(
                          child: Text(
                            _searchTerm.isEmpty
                                ? 'No products yet'
                                : 'No matching products',
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                        itemCount: products.length,
                        itemBuilder: (context, index) =>
                            _productTile(products[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openProductForm,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
    );
  }

  Widget _productTile(DocumentSnapshot<Map<String, dynamic>> product) {
    final data = product.data() ?? {};
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showProduct(product),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo[50],
          child: const Icon(Icons.grid_view, color: Colors.indigo),
        ),
        title: Text(
          data['productName']?.toString() ?? 'Unnamed product',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${data['productCode'] ?? '-'}  •  ${data['brand'] ?? '-'}  •  ${data['size'] ?? '-'}\nStatus: ${data['status'] ?? 'Active'}',
        ),
        isThreeLine: false,
        trailing: PopupMenuButton<String>(
          onSelected: (value) => value == 'edit'
              ? _openProductForm(product)
              : _deleteProduct(product),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
          icon: const Icon(Icons.more_vert),
        ),
      ),
    );
  }
}

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final DocumentSnapshot<Map<String, dynamic>>? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firebaseService = FirebaseService();
  late final Map<String, TextEditingController> _controllers;
  String _status = 'Active';
  bool _saving = false;

  static const _fields = [
    ('productCode', 'Product code'),
    ('productName', 'Product name'),
    ('brand', 'Brand'),
    ('design', 'Design'),
    ('color', 'Color'),
    ('size', 'Size'),
    ('thickness', 'Thickness (mm)'),
    ('finish', 'Finish'),
    ('piecesPerBox', 'Pieces per box'),
    ('coveragePerBox', 'Coverage per box (sqm)'),
    ('pricePerBox', 'Price per box'),
    ('pricePerSqm', 'Price per sqm'),
    ('pricePerSqft', 'Price per sqft'),
    ('reorderPoint', 'Reorder point'),
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.product?.data() ?? {};
    _controllers = {
      for (final field in _fields)
        field.$1: TextEditingController(text: '${data[field.$1] ?? ''}'),
    };
    _status = data['status']?.toString() ?? 'Active';
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final values = <String, dynamic>{};
    for (final field in _fields) {
      final value = _controllers[field.$1]!.text.trim();
      values[field.$1] =
          ['thickness', 'piecesPerBox', 'reorderPoint'].contains(field.$1)
          ? num.tryParse(value) ?? 0
          : [
              'coveragePerBox',
              'pricePerBox',
              'pricePerSqm',
              'pricePerSqft',
            ].contains(field.$1)
          ? num.tryParse(value) ?? 0
          : value;
    }
    values['status'] = _status;
    values['updatedAt'] = FieldValue.serverTimestamp();
    try {
      final collection = _firebaseService.getFirestore().collection('products');
      if (widget.product == null) {
        values['createdAt'] = FieldValue.serverTimestamp();
        await collection.add(values);
      } else {
        await collection.doc(widget.product!.id).update(values);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save product: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit product' : 'Add product'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ..._fields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextFormField(
                  controller: _controllers[field.$1],
                  keyboardType:
                      field.$1 == 'productName' ||
                          field.$1 == 'brand' ||
                          field.$1 == 'design' ||
                          field.$1 == 'color' ||
                          field.$1 == 'size' ||
                          field.$1 == 'finish' ||
                          field.$1 == 'productCode'
                      ? TextInputType.text
                      : const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: field.$2,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Active', child: Text('Active')),
                DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
              ],
              onChanged: (value) => setState(() => _status = value ?? 'Active'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving...' : 'Save product'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
