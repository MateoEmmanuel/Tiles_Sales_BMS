import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/firebase_service.dart';
import 'connection_status_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    this.showAppBar = true,
    this.showFloatingActions = true,
    this.showDashboard = true,
    this.showProductList = true,
  });

  final bool showAppBar;
  final bool showFloatingActions;
  final bool showDashboard;
  final bool showProductList;

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

  CollectionReference<Map<String, dynamic>> get _inventory =>
      _firebaseService.getFirestore().collection('inventory');

  Future<void> _openProductForm([
    DocumentSnapshot<Map<String, dynamic>>? product,
  ]) async {
    final newProductId = await showDialog<String>(
      context: context,
      builder: (_) => ProductFormScreen(product: product),
    );
    if (mounted && newProductId != null) {
      await _openStockInventory(initialProductId: newProductId);
    }
  }

  Future<void> _openStockInventory({String? initialProductId}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _StockInventoryDialog(
        initialProductId: initialProductId,
        products: _products,
        inventory: _inventory,
      ),
    );
  }

  Future<void> _openDamageReport({String? initialProductId}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _StockInventoryDialog(
        initialProductId: initialProductId,
        products: _products,
        inventory: _inventory,
        damageMode: true,
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.amber
                  : Colors.white,
            ),
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
      builder: (dialogContext) => AlertDialog(
        title: Text(data['productName']?.toString() ?? 'Product details'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              children: [
                ..._productFields(data).entries.map(
                  (entry) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: Text(entry.value, textAlign: TextAlign.right),
                  ),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: data['status']?.toString().toLowerCase() != 'inactive',
                  title: const Text('Active product'),
                  onChanged: (value) async {
                    await _setProductStatus(product, value);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deleteProduct(product);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.amber
                  : Colors.white,
            ),
            child: const Text('Delete'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
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
    'Maximum stock': '${data['maximumStock'] ?? '-'}',
    'Status': '${data['status'] ?? '-'}',
  };

  Future<void> _setProductStatus(
    DocumentSnapshot<Map<String, dynamic>> product,
    bool isActive,
  ) async {
    try {
      await product.reference.update({
        'status': isActive ? 'active' : 'inactive',
      });
    } catch (error) {
      _showError('Could not update product status: $error');
    }
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _inventoryProductId(Map<String, dynamic> data) {
    final productId = data['productId'] ?? data['product_dID'];
    if (productId is DocumentReference) return productId.id;
    return productId?.toString();
  }

  double _stockFor(
    DocumentSnapshot<Map<String, dynamic>> product,
    Map<String, dynamic> inventory,
  ) {
    return _number(inventory['quantityOnHand'] ?? inventory['current_stock']);
  }

  double _reorderPoint(DocumentSnapshot<Map<String, dynamic>> product) {
    return _number(product.data()?['reorderPoint']);
  }

  String _stockStatus(
    DocumentSnapshot<Map<String, dynamic>> product,
    Map<String, dynamic> inventory,
  ) {
    final stock = _stockFor(product, inventory);
    if (stock <= 0) return 'Out of stock';
    if (stock <= _reorderPoint(product)) return 'Low stock';
    return 'In stock';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
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
            )
          : null,
      body: !_firebaseService.isInitialized
          ? _buildUnavailableBody()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _products.orderBy('productName').snapshots(),
              builder: (context, productSnapshot) {
                if (productSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load products.\n${productSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (!productSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _inventory.snapshots(),
                  builder: (context, inventorySnapshot) {
                    final Map<String, Map<String, dynamic>> inventoryByProduct =
                        {
                          for (final item in inventorySnapshot.data?.docs ?? [])
                            if (_inventoryProductId(item.data()) != null)
                              _inventoryProductId(item.data())!: item.data(),
                        };
                    if (widget.showDashboard && !widget.showProductList) {
                      return _buildDashboardPanel(
                        productSnapshot.data!.docs,
                        inventoryByProduct,
                      );
                    }
                    if (!widget.showDashboard && widget.showProductList) {
                      return _buildProductInventoryPanel(
                        productSnapshot.data!.docs,
                        inventoryByProduct,
                        inventorySnapshot.hasError,
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 900;
                        final panels = [
                          _buildDashboardPanel(
                            productSnapshot.data!.docs,
                            inventoryByProduct,
                          ),
                          _buildProductInventoryPanel(
                            productSnapshot.data!.docs,
                            inventoryByProduct,
                            inventorySnapshot.hasError,
                          ),
                        ];
                        return wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: panels[0]),
                                  const VerticalDivider(width: 1),
                                  Expanded(child: panels[1]),
                                ],
                              )
                            : Column(
                                children: [
                                  Expanded(child: panels[0]),
                                  const Divider(height: 1),
                                  Expanded(child: panels[1]),
                                ],
                              );
                      },
                    );
                  },
                );
              },
            ),
      floatingActionButton: widget.showFloatingActions
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  onPressed: _openProductForm,
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.extended(
                  onPressed: _openStockInventory,
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Stock Inventory'),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.extended(
                  onPressed: _openDamageReport,
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.warning_amber_outlined),
                  label: const Text('Report damage'),
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildUnavailableBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: (value) =>
                setState(() => _searchTerm = value.trim().toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Search products...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const Expanded(
          child: Center(child: Text('Firebase is not initialized')),
        ),
      ],
    );
  }

  Widget _buildDashboardPanel(
    List<DocumentSnapshot<Map<String, dynamic>>> products,
    Map<String, Map<String, dynamic>> inventory,
  ) {
    final stocks = [
      for (final product in products)
        _stockFor(product, inventory[product.id] ?? {}),
    ];
    final totalStock = stocks.fold<double>(0, (total, stock) => total + stock);
    final lowStock = products
        .where(
          (product) =>
              _stockStatus(product, inventory[product.id] ?? {}) == 'Low stock',
        )
        .length;
    final outOfStock = products
        .where(
          (product) =>
              _stockStatus(product, inventory[product.id] ?? {}) ==
              'Out of stock',
        )
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        _sectionHeading('Inventory overview', 'Live stock health at a glance'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 104,
          children: [
            _metricCard(
              'Total products',
              '${products.length}',
              Icons.grid_view,
            ),
            _metricCard(
              'Total stock',
              _formatNumber(totalStock),
              Icons.inventory_2_outlined,
            ),
            _metricCard(
              'Low stock',
              '$lowStock',
              Icons.warning_amber_outlined,
              color: Colors.orange,
            ),
            _metricCard(
              'Out of stock',
              '$outOfStock',
              Icons.remove_shopping_cart_outlined,
              color: Colors.red,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _sectionHeading('Stock quantity by product', 'Compare available units'),
        const SizedBox(height: 10),
        _chartCard(
          products.isEmpty
              ? const Center(child: Text('No product stock data yet'))
              : _StockBarChart(
                  products: products,
                  stocks: stocks,
                  reorderPoints: [
                    for (final product in products) _reorderPoint(product),
                  ],
                  formatNumber: _formatNumber,
                ),
        ),
        const SizedBox(height: 24),
        _sectionHeading('Stock status', 'Products grouped by availability'),
        const SizedBox(height: 10),
        _chartCard(
          _StockDonutChart(
            inStock: products.length - lowStock - outOfStock,
            lowStock: lowStock,
            outOfStock: outOfStock,
          ),
        ),
        const SizedBox(height: 24),
        _sectionHeading('Low stock products', 'Restock these products first'),
        const SizedBox(height: 10),
        _lowStockTable(products, inventory),
        const SizedBox(height: 28),
        _sectionHeading(
          'Sales analytics',
          'Income and outstanding customer balances',
        ),
        const SizedBox(height: 10),
        const _SalesAnalyticsPanel(),
      ],
    );
  }

  Widget _buildProductInventoryPanel(
    List<DocumentSnapshot<Map<String, dynamic>>> allProducts,
    Map<String, Map<String, dynamic>> inventory,
    bool inventoryError,
  ) {
    final products = allProducts.where((product) {
      final data = product.data() ?? <String, dynamic>{};
      final searchable = [
        data['productName'],
        data['brand'],
        data['design'],
      ].join(' ').toLowerCase();
      return searchable.contains(_searchTerm);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeading('Products', 'Search and manage your catalog'),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _searchTerm = value.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search products...',
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
                  filled: true,
                  fillColor: Colors.indigo.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (inventoryError)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Inventory collection unavailable; stock is shown as 0.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Text(
                    _searchTerm.isEmpty
                        ? 'No products yet'
                        : 'No matching products',
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: products.length,
                  itemBuilder: (context, index) => _productTile(
                    products[index],
                    inventory[products[index].id] ?? {},
                  ),
                ),
        ),
      ],
    );
  }

  Widget _sectionHeading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 3),
      Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
    ],
  );

  Widget _metricCard(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    final accent = color ?? Colors.indigo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 18, color: accent),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _chartCard(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.indigo.withValues(alpha: 0.10)),
    ),
    child: child,
  );

  Widget _lowStockTable(
    List<DocumentSnapshot<Map<String, dynamic>>> products,
    Map<String, Map<String, dynamic>> inventory,
  ) {
    final lowProducts = products.where((product) {
      final status = _stockStatus(product, inventory[product.id] ?? {});
      return status == 'Low stock' || status == 'Out of stock';
    }).toList();
    if (lowProducts.isEmpty) {
      return _chartCard(const Text('No products need restocking.'));
    }
    return _chartCard(
      Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Product',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 54,
                child: Text(
                  'Stock',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 84,
                child: Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Divider(),
          ...lowProducts.map((product) {
            final status = _stockStatus(product, inventory[product.id] ?? {});
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      product.data()?['productName']?.toString() ?? 'Unnamed',
                    ),
                  ),
                  SizedBox(
                    width: 54,
                    child: Text(
                      _formatNumber(
                        _stockFor(product, inventory[product.id] ?? {}),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      status == 'Out of stock' ? 'Out' : 'Low',
                      style: TextStyle(
                        color: status == 'Out of stock'
                            ? Colors.red
                            : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  Widget _productTile(
    DocumentSnapshot<Map<String, dynamic>> product,
    Map<String, dynamic> inventory,
  ) {
    final data = product.data() ?? {};
    final stock = _stockFor(product, inventory);
    final stockStatus = _stockStatus(product, inventory);
    final statusColor = stockStatus == 'In stock'
        ? Colors.green
        : stockStatus == 'Low stock'
        ? Colors.orange
        : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.indigo.withValues(alpha: 0.10)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        onTap: () => _showProduct(product),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo[50],
          child: const Icon(Icons.grid_view, color: Colors.indigo),
        ),
        title: Text(
          data['productName']?.toString() ?? 'Unnamed product',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${data['brand'] ?? '-'}  •  ${data['size'] ?? '-'}'),
              const SizedBox(height: 5),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  Text(
                    'Stock: ${_formatNumber(stock)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '● ${data['status'] ?? 'Active'}',
                    style: TextStyle(
                      color: data['status'] == 'Inactive'
                          ? Colors.grey
                          : Colors.indigo,
                    ),
                  ),
                  Text(
                    '● $stockStatus',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        isThreeLine: true,
        trailing: Switch.adaptive(
          value: data['status']?.toString().toLowerCase() != 'inactive',
          onChanged: (value) => _setProductStatus(product, value),
          thumbIcon: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Icon(Icons.check, size: 14)
                : const Icon(Icons.close, size: 14),
          ),
        ),
      ),
    );
  }
}

class _StockInventoryDialog extends StatefulWidget {
  const _StockInventoryDialog({
    required this.products,
    required this.inventory,
    this.initialProductId,
    this.damageMode = false,
  });

  final CollectionReference<Map<String, dynamic>> products;
  final CollectionReference<Map<String, dynamic>> inventory;
  final String? initialProductId;
  final bool damageMode;

  @override
  State<_StockInventoryDialog> createState() => _StockInventoryDialogState();
}

class _StockInventoryDialogState extends State<_StockInventoryDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _reasonController;
  String? _selectedProductId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedProductId = widget.initialProductId;
    _quantityController = TextEditingController(text: '1');
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _inventoryProductId(Map<String, dynamic> data) {
    final productId = data['productId'] ?? data['product_dID'];
    if (productId is DocumentReference) return productId.id;
    return productId?.toString();
  }

  String _formatNumber(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  void _selectProduct(String? productId) {
    setState(() => _selectedProductId = productId);
  }

  Future<void> _saveRestock() async {
    final productId = _selectedProductId;
    final quantity = int.tryParse(_quantityController.text.trim());
    if (productId == null) {
      _showError('Select a product first.');
      return;
    }
    if (quantity == null || quantity <= 0) {
      _showError('Restock quantity must be greater than 0.');
      return;
    }
    if (widget.damageMode && _reasonController.text.trim().isEmpty) {
      _showError('Enter the damage incident reason.');
      return;
    }

    setState(() => _saving = true);
    try {
      var previousStock = 0.0;
      var inventoryQuery = await widget.inventory
          .where('productId', isEqualTo: widget.products.doc(productId))
          .limit(1)
          .get();
      if (inventoryQuery.docs.isEmpty) {
        inventoryQuery = await widget.inventory
            .where('product_dID', isEqualTo: productId)
            .limit(1)
            .get();
      }
      if (inventoryQuery.docs.isEmpty) {
        if (widget.damageMode) {
          throw StateError('No inventory record exists for this product.');
        }
        await widget.inventory.add({
          'productId': widget.products.doc(productId),
          'quantityOnHand': quantity,
          'product_dID': productId,
          'current_stock': quantity,
        });
      } else {
        final inventoryDocument = inventoryQuery.docs.first;
        previousStock = _number(
          inventoryDocument.data()['quantityOnHand'] ??
              inventoryDocument.data()['current_stock'],
        );
        final updatedStock = widget.damageMode
            ? previousStock - quantity
            : previousStock + quantity;
        if (widget.damageMode && updatedStock < 0) {
          throw StateError('Damaged quantity cannot exceed current stock.');
        }
        await inventoryDocument.reference.update({
          'quantityOnHand': updatedStock,
          'current_stock': updatedStock,
        });
      }
      await FirebaseFirestore.instance.collection('stock_movements').add({
        'productId': widget.products.doc(productId),
        'movementType': widget.damageMode ? 'damaged' : 'restock',
        'quantity': quantity,
        'unit': 'box',
        'previousQuantity': previousStock,
        'newQuantity': widget.damageMode
            ? previousStock - quantity
            : previousStock + quantity,
        'reason': widget.damageMode
            ? _reasonController.text.trim()
            : 'Manual restock',
        'movementDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.damageMode
                  ? 'Damage report recorded'
                  : 'Inventory updated successfully',
            ),
          ),
        );
      }
    } catch (error) {
      setState(() => _saving = false);
      _showError('Could not update inventory: $error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.products.orderBy('productName').snapshots(),
          builder: (context, productSnapshot) {
            if (productSnapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load products.\n${productSnapshot.error}',
                ),
              );
            }
            if (!productSnapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              );
            }
            final products = productSnapshot.data!.docs;
            if (products.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Add a product before updating stock.'),
              );
            }
            final productIds = products.map((product) => product.id).toSet();
            final selectedProductId = productIds.contains(_selectedProductId)
                ? _selectedProductId!
                : products.first.id;
            if (selectedProductId != _selectedProductId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _selectedProductId = selectedProductId);
                }
              });
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.inventory.snapshots(),
              builder: (context, inventorySnapshot) {
                final inventoryDocument = inventorySnapshot.data?.docs.where(
                  (document) =>
                      _inventoryProductId(document.data()) == selectedProductId,
                );
                final inventoryData =
                    inventoryDocument != null && inventoryDocument.isNotEmpty
                    ? inventoryDocument.first.data()
                    : <String, dynamic>{};
                final currentStock = _number(
                  inventoryData['quantityOnHand'] ??
                      inventoryData['current_stock'],
                );
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.damageMode
                                  ? 'Report damaged stock'
                                  : 'Stock Inventory',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 420;
                          final idDropdown = _productDropdown(
                            label: 'Product',
                            products: products,
                            selectedProductId: selectedProductId,
                            labelBuilder: (product) =>
                                product.data()?['productName']?.toString() ??
                                'Unnamed product',
                          );
                          final nameDropdown = _productDropdown(
                            label: 'Product Name',
                            products: products,
                            selectedProductId: selectedProductId,
                            labelBuilder: (product) =>
                                product.data()?['productName']?.toString() ??
                                'Unnamed product',
                          );
                          return stacked
                              ? Column(
                                  children: [
                                    idDropdown,
                                    const SizedBox(height: 12),
                                    nameDropdown,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: idDropdown),
                                    const SizedBox(width: 12),
                                    Expanded(child: nameDropdown),
                                  ],
                                );
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Current stock: ${_formatNumber(currentStock)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.damageMode
                                  ? 'Damaged quantity'
                                  : 'Restock quantity',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            onPressed: _saving ? null : _decrementQuantity,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          SizedBox(
                            width: 72,
                            child: TextField(
                              controller: _quantityController,
                              enabled: !_saving,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          IconButton(
                            onPressed: _saving ? null : _incrementQuantity,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (widget.damageMode) ...[
                        TextField(
                          controller: _reasonController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Damage incident reason',
                            hintText: 'Describe the damage or incident',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _saving ? null : _saveRestock,
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _productDropdown({
    required String label,
    required List<DocumentSnapshot<Map<String, dynamic>>> products,
    required String selectedProductId,
    required String Function(DocumentSnapshot<Map<String, dynamic>>)
    labelBuilder,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: selectedProductId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final product in products)
          DropdownMenuItem(
            value: product.id,
            child: Text(labelBuilder(product), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _saving ? null : _selectProduct,
    );
  }

  void _decrementQuantity() {
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    _quantityController.text = '${quantity > 1 ? quantity - 1 : 1}';
    setState(() {});
  }

  void _incrementQuantity() {
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    _quantityController.text = '${quantity + 1}';
    setState(() {});
  }
}

class _StockBarChart extends StatelessWidget {
  const _StockBarChart({
    required this.products,
    required this.stocks,
    required this.reorderPoints,
    required this.formatNumber,
  });

  final List<DocumentSnapshot<Map<String, dynamic>>> products;
  final List<double> stocks;
  final List<double> reorderPoints;
  final String Function(double) formatNumber;

  Color _barColor(double stock, double reorderPoint) {
    if (stock <= 0) return Colors.red;
    if (stock <= reorderPoint) return Colors.orange;
    if (stock <= reorderPoint * 2) return Colors.green;
    return Colors.indigo;
  }

  @override
  Widget build(BuildContext context) {
    final maxStock = stocks.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    return Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _legend(Colors.indigo, 'Plenty'),
            _legend(Colors.green, 'Ready soon'),
            _legend(Colors.orange, 'Low stock'),
            _legend(Colors.red, 'Out of stock'),
          ],
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < products.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    products[index].data()?['productName']?.toString() ??
                        'Unnamed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: stocks[index] <= 0 ? Colors.red : null,
                      fontWeight: stocks[index] <= 0
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 12,
                      value: maxStock == 0 ? 0 : stocks[index] / maxStock,
                      backgroundColor: Colors.indigo.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _barColor(stocks[index], reorderPoints[index]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 38,
                  child: Text(
                    formatNumber(stocks[index]),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _legend(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11)),
    ],
  );
}

class _StockDonutChart extends StatelessWidget {
  const _StockDonutChart({
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
  });

  final int inStock;
  final int lowStock;
  final int outOfStock;

  @override
  Widget build(BuildContext context) {
    final total = inStock + lowStock + outOfStock;
    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _DonutPainter(
              inStock: inStock,
              lowStock: lowStock,
              outOfStock: outOfStock,
            ),
            child: Center(
              child: Text(
                '$total',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legend(Colors.green, 'In stock', inStock),
            _legend(Colors.orange, 'Low stock', lowStock),
            _legend(Colors.red, 'Out of stock', outOfStock),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color color, String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('$label  $value'),
      ],
    ),
  );
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.inStock,
    required this.lowStock,
    required this.outOfStock,
  });

  final int inStock;
  final int lowStock;
  final int outOfStock;

  @override
  void paint(Canvas canvas, Size size) {
    final total = inStock + lowStock + outOfStock;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    if (total == 0) {
      paint.color = Colors.grey.shade300;
      canvas.drawArc(rect.deflate(10), 0, 2 * 3.1415926535, false, paint);
      return;
    }
    var start = -3.1415926535 / 2;
    for (final segment in [
      (inStock, Colors.green),
      (lowStock, Colors.orange),
      (outOfStock, Colors.red),
    ]) {
      if (segment.$1 == 0) continue;
      final sweep = 2 * 3.1415926535 * segment.$1 / total;
      paint.color = segment.$2;
      canvas.drawArc(rect.deflate(10), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.inStock != inStock ||
      oldDelegate.lowStock != lowStock ||
      oldDelegate.outOfStock != outOfStock;
}

class _SalesAnalyticsPanel extends StatelessWidget {
  const _SalesAnalyticsPanel();

  @override
  Widget build(BuildContext context) {
    final sales = FirebaseService().getFirestore().collection('sales');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: sales.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _analyticsCard(const Text('Sales data is not available yet.'));
        }
        final records = snapshot.data?.docs ?? [];
        final now = DateTime.now();
        final monthRecords = records.where((record) {
          final data = record.data();
          final value = data['saleDate'];
          final date = value is Timestamp ? value.toDate() : null;
          return date != null &&
              date.year == now.year &&
              date.month == now.month;
        }).toList();
        final income = monthRecords.fold<double>(
          0,
          (total, record) => total + _amount(record.data()['totalAmount']),
        );
        final balanceDue = records.fold<double>(
          0,
          (total, record) => total + _amount(record.data()['balanceDue']),
        );
        final paid = monthRecords.fold<double>(
          0,
          (total, record) => total + _amount(record.data()['amountPaid']),
        );
        final bars = _dailyIncome(monthRecords, now);

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _AnalyticsMetric(
                    'This month income',
                    'PHP ${_formatAmount(income)}',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AnalyticsMetric(
                    'Collected',
                    'PHP ${_formatAmount(paid)}',
                    Icons.payments_outlined,
                    Colors.indigo,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AnalyticsMetric(
                    'Customer balances',
                    'PHP ${_formatAmount(balanceDue)}',
                    Icons.account_balance_wallet_outlined,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _analyticsCard(
              monthRecords.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No sales recorded this month'),
                      ),
                    )
                  : _SalesBarChart(values: bars),
            ),
          ],
        );
      },
    );
  }

  List<double> _dailyIncome(
    List<DocumentSnapshot<Map<String, dynamic>>> records,
    DateTime now,
  ) {
    final days = List<double>.filled(now.day, 0);
    for (final record in records) {
      final data = record.data() ?? <String, dynamic>{};
      final value = data['saleDate'];
      final date = value is Timestamp ? value.toDate() : null;
      if (date != null && date.day <= days.length) {
        days[date.day - 1] += _amount(data['totalAmount']);
      }
    }
    return days;
  }

  double _amount(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
  String _formatAmount(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  Widget _analyticsCard(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.indigo.withValues(alpha: 0.10)),
    ),
    child: child,
  );
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 92,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.14)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, size: 18, color: color),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w800, color: color),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    ),
  );
}

class _SalesBarChart extends StatelessWidget {
  const _SalesBarChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < values.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: maxValue == 0
                              ? 0
                              : values[index] / maxValue,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.indigo.withValues(alpha: 0.78),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${index + 1}', style: const TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ),
        ],
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
  bool _saving = false;

  static const _fields = [
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
    ('maximumStock', 'Maximum stock (optional)'),
  ];

  @override
  void initState() {
    super.initState();
    final data = widget.product?.data() ?? {};
    _controllers = {
      for (final field in _fields)
        field.$1: TextEditingController(text: '${data[field.$1] ?? ''}'),
    };
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
          [
            'thickness',
            'piecesPerBox',
            'reorderPoint',
            'maximumStock',
          ].contains(field.$1)
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
    if (widget.product == null) values['status'] = 'active';
    values['updatedAt'] = FieldValue.serverTimestamp();
    try {
      final firestore = _firebaseService.getFirestore();
      final collection = firestore.collection('products');
      if (widget.product == null) {
        final productReference = collection.doc();
        values['createdAt'] = FieldValue.serverTimestamp();
        final inventoryReference = firestore.collection('inventory').doc();
        final batch = firestore.batch();
        batch.set(productReference, values);
        batch.set(inventoryReference, {
          'productId': productReference,
          'quantityOnHand': 0,
          'product_dID': productReference.id,
          'current_stock': 0,
        });
        await batch.commit();
        if (mounted) Navigator.pop(context, productReference.id);
      } else {
        await collection.doc(widget.product!.id).update(values);
        if (mounted) Navigator.pop(context);
      }
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
    return AlertDialog(
      title: Text(isEditing ? 'Edit product' : 'Add product'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
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
                            field.$1 == 'finish'
                        ? TextInputType.text
                        : const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: field.$2,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? 'Saving...' : 'Save product'),
        ),
      ],
    );
  }
}
