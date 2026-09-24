import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class CashierShell extends StatefulWidget {
  const CashierShell({super.key});

  @override
  State<CashierShell> createState() => _CashierShellState();
}

class _CashierShellState extends State<CashierShell> {
  final _firebaseService = FirebaseService();
  int _selectedIndex = 0;

  static const _destinations = [
    ('Checkout', Icons.point_of_sale_outlined),
    ('Transactions', Icons.receipt_long_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = _firebaseService.isInitialized
        ? _firebaseService
              .getFirestore()
              .collection('app_settings')
              .doc('settings')
        : null;
    if (settings == null) return _buildShell(const _BusinessSettings());

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: settings.snapshots(),
      builder: (context, snapshot) =>
          _buildShell(_BusinessSettings.fromMap(snapshot.data?.data())),
    );
  }

  Widget _buildShell(_BusinessSettings settings) {
    final baseTheme = Theme.of(context);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF176B6B),
      brightness: Brightness.light,
    );

    return Theme(
      data: baseTheme.copyWith(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFFAF9F6),
        appBarTheme: baseTheme.appBarTheme.copyWith(
          backgroundColor: const Color(0xFFFAF9F6),
          surfaceTintColor: const Color(0xFFFAF9F6),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFFAF9F6),
          surfaceTintColor: const Color(0xFFFAF9F6),
          titleSpacing: 8,
          leadingWidth: 280,
          leading: _BusinessBrand(settings: settings),
          title: _buildQuickNavigation(),
          actions: [_buildUserMenu(), const SizedBox(width: 8)],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _CheckoutView(firebaseService: _firebaseService),
            _CashierTransactions(firebaseService: _firebaseService),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickNavigation() {
    final compact = MediaQuery.sizeOf(context).width < 980;
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _destinations[_selectedIndex].$1,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          PopupMenuButton<int>(
            tooltip: 'Quick navigation',
            onSelected: (value) => setState(() => _selectedIndex = value),
            icon: const Icon(Icons.menu_open),
            itemBuilder: (context) => [
              for (var index = 0; index < _destinations.length; index++)
                PopupMenuItem(
                  value: index,
                  child: ListTile(
                    dense: true,
                    leading: Icon(_destinations[index].$2),
                    title: Text(_destinations[index].$1),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < _destinations.length; index++)
          TextButton.icon(
            onPressed: () => setState(() => _selectedIndex = index),
            icon: Icon(_destinations[index].$2, size: 17),
            label: Text(_destinations[index].$1),
            style: TextButton.styleFrom(
              foregroundColor: _selectedIndex == index
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade700,
              textStyle: TextStyle(
                fontSize: 12,
                fontWeight: _selectedIndex == index
                    ? FontWeight.w800
                    : FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Open staff profile',
      onSelected: (value) {
        if (value == 'profile') _showProfileDialog();
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'profile', child: Text('Staff information')),
        PopupMenuItem(
          enabled: false,
          value: 'status',
          child: Text('Role: [user not loaded]'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.person_outline, size: 19),
            ),
            const SizedBox(width: 8),
            const Text(
              '[user not loaded]',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Staff information'),
        content: const Text(
          'No staff account is loaded yet. Staff profile data can be connected later through Firebase Authentication and the users collection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _BusinessBrand extends StatelessWidget {
  const _BusinessBrand({required this.settings});

  final _BusinessSettings settings;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Return to login page',
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (_) => false),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Row(
            children: [
              _BusinessIcon(logoUrl: settings.logoUrl),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  settings.businessName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessIcon extends StatelessWidget {
  const _BusinessIcon({this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim() ?? '';
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(Icons.business_outlined)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.business_outlined),
            ),
    );
  }
}

class _BusinessSettings {
  const _BusinessSettings({
    this.businessName = 'Tiles Selling BMS',
    this.logoUrl,
  });

  final String businessName;
  final String? logoUrl;

  factory _BusinessSettings.fromMap(Map<String, dynamic>? data) {
    final name = data?['businessName']?.toString().trim();
    return _BusinessSettings(
      businessName: name?.isNotEmpty == true ? name! : 'Tiles Selling BMS',
      logoUrl: data?['businessLogoUrl']?.toString(),
    );
  }
}

class _CheckoutView extends StatefulWidget {
  const _CheckoutView({required this.firebaseService});

  final FirebaseService firebaseService;

  @override
  State<_CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<_CheckoutView> {
  final _searchController = TextEditingController();
  final _customerController = TextEditingController();
  final _paymentController = TextEditingController();
  final Map<String, _CashierCartItem> _cart = {};
  String _searchTerm = '';
  String _discountMode = 'percent';
  final _discountController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _customerController.dispose();
    _paymentController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.firebaseService.isInitialized) {
      return const Center(child: Text('Firebase is not initialized'));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.firebaseService
          .getFirestore()
          .collection('products')
          .snapshots(),
      builder: (context, productSnapshot) {
        if (productSnapshot.hasError) {
          return Center(
            child: Text('Could not load products.\n${productSnapshot.error}'),
          );
        }
        if (!productSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.firebaseService
              .getFirestore()
              .collection('inventory')
              .snapshots(),
          builder: (context, inventorySnapshot) {
            if (inventorySnapshot.hasError) {
              return Center(
                child: Text(
                  'Could not load inventory.\n${inventorySnapshot.error}',
                ),
              );
            }
            if (!inventorySnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final stockByProduct = <String, double>{};
            for (final inventory in inventorySnapshot.data!.docs) {
              final data = inventory.data();
              final reference = data['productId'];
              final productId = reference is DocumentReference
                  ? reference.id
                  : (data['product_dID'] ?? '').toString();
              stockByProduct[productId] = _cashierNumber(
                data['availableQuantity'] ??
                    data['quantityOnHand'] ??
                    data['current_stock'],
              );
            }
            final products = productSnapshot.data!.docs.where((product) {
              final data = product.data();
              final text =
                  '${data['productName'] ?? ''} ${data['brand'] ?? ''} ${data['design'] ?? ''}'
                      .toLowerCase();
              final isActive =
                  data['status']?.toString().toLowerCase() != 'inactive';
              return isActive &&
                  text.contains(_searchTerm) &&
                  (stockByProduct[product.id] ?? 0) > 0;
            }).toList();
            return LayoutBuilder(
              builder: (context, constraints) {
                final productPanel = _buildProductPanel(
                  products,
                  stockByProduct,
                );
                final cartPanel = _buildCartPanel(stockByProduct);
                if (constraints.maxWidth < 850) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
                    children: [
                      SizedBox(height: 500, child: productPanel),
                      const SizedBox(height: 16),
                      SizedBox(height: 620, child: cartPanel),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: productPanel),
                    const SizedBox(width: 16),
                    SizedBox(width: 380, child: cartPanel),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProductPanel(
    List<DocumentSnapshot<Map<String, dynamic>>> products,
    Map<String, double> stockByProduct,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 22, 0, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cashier checkout',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          'Listen to the customer order and punch it into the POS.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _searchController,
          onChanged: (value) =>
              setState(() => _searchTerm = value.trim().toLowerCase()),
          decoration: InputDecoration(
            labelText: 'Search products',
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: products.isEmpty
              ? const _CashierEmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No matching products',
                  message: 'Try a different product search.',
                )
              : ListView.separated(
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _productTile(
                    products[index],
                    stockByProduct[products[index].id] ?? 0,
                  ),
                ),
        ),
      ],
    ),
  );

  Widget _productTile(
    DocumentSnapshot<Map<String, dynamic>> product,
    double stock,
  ) {
    final data = product.data();
    final price = _cashierNumber(
      data?['pricePerBox'] ?? data?['price'] ?? data?['unitPrice'],
    );
    final item = _cart[product.id];
    return Card(
      elevation: 0,
      child: ListTile(
        onTap: () => _showProductDetails(product, stock),
        leading: const CircleAvatar(child: Icon(Icons.grid_view_outlined)),
        title: Text(
          data?['productName']?.toString() ?? 'Product',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${data?['brand'] ?? ''} ${data?['size'] ?? ''}  |  Stock: ${_cashierMoney(stock)}'
              .trim(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PHP ${_cashierMoney(price)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            IconButton(
              onPressed: item == null
                  ? null
                  : () => _changeQuantity(product.id, -1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('${item?.quantity ?? 0}'),
            IconButton(
              onPressed: stock <= (item?.quantity ?? 0)
                  ? null
                  : () => _addProduct(product, stock),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartPanel(Map<String, double> stockByProduct) {
    final total = _cart.values.fold<double>(
      0,
      (amount, item) => amount + item.total,
    );
    final discount = _discountFor(total);
    final payable = total - discount;
    return Card(
      margin: const EdgeInsets.fromLTRB(0, 22, 24, 30),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current order',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _cart.isEmpty
                  ? const _CashierEmptyState(
                      icon: Icons.shopping_cart_outlined,
                      title: 'Cart is empty',
                      message: 'Tap a product to add it to the customer order.',
                    )
                  : ListView(
                      children: [
                        for (final item in _cart.values)
                          _cartRow(item, stockByProduct[item.productId] ?? 0),
                      ],
                    ),
            ),
            const Divider(height: 22),
            TextField(
              controller: _customerController,
              decoration: const InputDecoration(
                labelText: 'Customer name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Discount',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _discountMode,
                  items: const [
                    DropdownMenuItem(value: 'percent', child: Text('%')),
                    DropdownMenuItem(value: 'amount', child: Text('PHP')),
                  ],
                  onChanged: (value) => setState(() => _discountMode = value!),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _discountController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Discount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _paymentController,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount received',
                prefixText: 'PHP ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _CashierSummaryLine(
              label: 'Subtotal',
              value: 'PHP ${_cashierMoney(total)}',
            ),
            _CashierSummaryLine(
              label: 'Discount',
              value: '- PHP ${_cashierMoney(discount)}',
            ),
            _CashierSummaryLine(
              label: 'Total',
              value: 'PHP ${_cashierMoney(payable)}',
              emphasized: true,
            ),
            _CashierSummaryLine(
              label: 'Change',
              value:
                  'PHP ${_cashierMoney(_cashierNumber(_paymentController.text) - payable)}',
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _cart.isEmpty || _saving
                    ? null
                    : () => _completeSale(total, discount, payable),
                icon: const Icon(Icons.check),
                label: Text(_saving ? 'Saving...' : 'Complete sale'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartRow(_CashierCartItem item, double stock) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text('PHP ${_cashierMoney(item.price)} each'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _changeQuantity(item.productId, -1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 58,
          child: TextFormField(
            key: ValueKey('${item.productId}-${item.quantity}'),
            initialValue: '${item.quantity}',
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              border: OutlineInputBorder(),
            ),
            onFieldSubmitted: (value) =>
                _setQuantity(item.productId, int.tryParse(value), stock),
          ),
        ),
        IconButton(
          onPressed: item.quantity >= stock
              ? null
              : () => _changeQuantity(item.productId, 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    ),
  );

  void _addProduct(
    DocumentSnapshot<Map<String, dynamic>> product,
    double stock,
  ) {
    final data = product.data() ?? {};
    if (data['status']?.toString().toLowerCase() == 'inactive') return;
    final price = _cashierNumber(
      data['pricePerBox'] ?? data['price'] ?? data['unitPrice'],
    );
    setState(() {
      final current = _cart[product.id];
      if (current != null && current.quantity >= stock) return;
      if (current == null) {
        _cart[product.id] = _CashierCartItem(
          productId: product.id,
          name: data['productName']?.toString() ?? 'Product',
          price: price,
        );
      } else {
        current.quantity++;
      }
    });
  }

  void _showProductDetails(
    DocumentSnapshot<Map<String, dynamic>> product,
    double stock,
  ) {
    final data = product.data() ?? {};
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['productName']?.toString() ?? 'Product details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailLine('Brand', data['brand']),
              _detailLine('Design', data['design']),
              _detailLine('Color', data['color']),
              _detailLine('Size', data['size']),
              _detailLine('Finish', data['finish']),
              _detailLine('Unit', 'box'),
              _detailLine('Current stock', _cashierMoney(stock)),
              _detailLine(
                'Price per box',
                'PHP ${_cashierMoney(data['pricePerBox'] ?? data['price'])}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: stock <= (_cart[product.id]?.quantity ?? 0)
                ? null
                : () {
                    Navigator.pop(context);
                    _addProduct(product, stock);
                  },
            icon: const Icon(Icons.add),
            label: const Text('Add to order'),
          ),
        ],
      ),
    );
  }

  Widget _detailLine(String label, dynamic value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          (value?.toString().trim().isEmpty ?? true) ? '-' : value.toString(),
        ),
      ],
    ),
  );

  void _changeQuantity(String productId, int change) {
    setState(() {
      final item = _cart[productId];
      if (item == null) return;
      item.quantity += change;
      if (item.quantity <= 0) _cart.remove(productId);
    });
  }

  void _setQuantity(String productId, int? quantity, double stock) {
    if (quantity == null || quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a quantity of at least 1.')),
      );
      return;
    }
    if (quantity > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only ${_cashierMoney(stock)} units are currently in stock.',
          ),
        ),
      );
      return;
    }
    setState(() {
      final item = _cart[productId];
      if (item != null) item.quantity = quantity;
    });
  }

  double _discountFor(double subtotal) {
    final value = _cashierNumber(_discountController.text);
    final discount = _discountMode == 'percent'
        ? subtotal * value / 100
        : value;
    return discount.clamp(0, subtotal).toDouble();
  }

  Future<void> _completeSale(
    double subtotal,
    double discount,
    double total,
  ) async {
    final received = _cashierNumber(_paymentController.text);
    if (received < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount received is less than the order total.'),
        ),
      );
      return;
    }
    final stockError = await _checkCurrentStock();
    if (stockError != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(stockError)));
      }
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm final sale'),
        content: Text(
          'This transaction is final and cannot be returned.\n\n'
          'Total: PHP ${_cashierMoney(total)}\n\n'
          'Do you wish to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed with sale'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final firestore = widget.firebaseService.getFirestore();
      final sale = firestore.collection('sales').doc();
      final batch = firestore.batch();
      batch.set(sale, {
        'salesId': sale.id,
        'customerName': _customerController.text.trim().isEmpty
            ? 'Walk-in customer'
            : _customerController.text.trim(),
        'saleDate': Timestamp.now(),
        'subtotal': subtotal,
        'discountAmount': discount,
        'discountType': _discountMode,
        'discountValue': _cashierNumber(_discountController.text),
        'totalAmount': total,
        'amountPaid': received,
        'changeAmount': received - total,
        'paymentStatus': 'paid',
        'saleStatus': 'completed',
      });
      for (final item in _cart.values) {
        final inventoryQuery = await firestore
            .collection('inventory')
            .where('product_dID', isEqualTo: item.productId)
            .limit(1)
            .get();
        final inventoryDocs = inventoryQuery.docs.isEmpty
            ? await firestore
                  .collection('inventory')
                  .where(
                    'productId',
                    isEqualTo: firestore
                        .collection('products')
                        .doc(item.productId),
                  )
                  .limit(1)
                  .get()
            : inventoryQuery;
        if (inventoryDocs.docs.isEmpty) {
          throw StateError('Inventory record is missing for ${item.name}.');
        }
        final inventory = inventoryDocs.docs.first;
        final inventoryData = inventory.data();
        final stock = _cashierNumber(
          inventoryData['availableQuantity'] ??
              inventoryData['quantityOnHand'] ??
              inventoryData['current_stock'],
        );
        if (item.quantity > stock) {
          throw StateError(
            '${item.name} only has ${_cashierMoney(stock)} in stock.',
          );
        }
        final nextStock = stock - item.quantity;
        batch.update(inventory.reference, {
          'quantityOnHand': nextStock,
          'current_stock': nextStock,
          'availableQuantity': nextStock,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
        batch.set(firestore.collection('stock_movements').doc(), {
          'productId': firestore.collection('products').doc(item.productId),
          'movementType': 'sale',
          'quantity': item.quantity,
          'unit': 'box',
          'previousQuantity': stock,
          'newQuantity': nextStock,
          'relatedSaleId': sale,
          'reason': 'Cashier sale',
          'movementDate': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.set(sale.collection('items').doc(item.productId), {
          'productId': item.productId,
          'productName': item.name,
          'quantity': item.quantity,
          'unit': 'box',
          'unitPrice': item.price,
          'lineTotal': item.total,
        });
      }
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _cart.clear();
        _customerController.clear();
        _paymentController.clear();
        _discountController.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sale completed.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete sale: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _checkCurrentStock() async {
    final firestore = widget.firebaseService.getFirestore();
    for (final item in _cart.values) {
      var query = await firestore
          .collection('inventory')
          .where('product_dID', isEqualTo: item.productId)
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        query = await firestore
            .collection('inventory')
            .where(
              'productId',
              isEqualTo: firestore.collection('products').doc(item.productId),
            )
            .limit(1)
            .get();
      }
      if (query.docs.isEmpty) {
        return 'Inventory record is missing for ${item.name}.';
      }
      final data = query.docs.first.data();
      final stock = _cashierNumber(
        data['availableQuantity'] ??
            data['quantityOnHand'] ??
            data['current_stock'],
      );
      if (item.quantity > stock) {
        return '${item.name} only has ${_cashierMoney(stock)} in stock.';
      }
    }
    return null;
  }
}

class _CashierCartItem {
  _CashierCartItem({
    required this.productId,
    required this.name,
    required this.price,
  });
  final String productId;
  final String name;
  final double price;
  int quantity = 1;
  double get total => price * quantity;
}

class _CashierTransactions extends StatelessWidget {
  const _CashierTransactions({required this.firebaseService});

  final FirebaseService firebaseService;

  @override
  Widget build(BuildContext context) {
    if (!firebaseService.isInitialized) {
      return const Center(child: Text('Firebase is not initialized'));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: firebaseService.getFirestore().collection('sales').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load transactions.\n${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final sales = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: sales.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = sales[index].data();
            return ListTile(
              onTap: () => _showTransaction(context, sales[index]),
              tileColor: Theme.of(context).colorScheme.surface,
              title: Text(
                data['customerName']?.toString() ?? 'Walk-in customer',
              ),
              subtitle: Text(
                data['salesId']?.toString() ?? 'Receipt not recorded',
              ),
              trailing: Text('PHP ${_cashierMoney(data['totalAmount'])}'),
            );
          },
        );
      },
    );
  }

  void _showTransaction(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> sale,
  ) {
    final data = sale.data() ?? {};
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['customerName']?.toString() ?? 'Transaction details'),
        content: SizedBox(
          width: 460,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: sale.reference.collection('items').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Could not load purchased items.\n${snapshot.error}',
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cashierDetail('Receipt', data['salesId']),
                    _cashierDetail('Date', _cashierDate(data['saleDate'])),
                    _cashierDetail(
                      'Subtotal',
                      'PHP ${_cashierMoney(data['subtotal'])}',
                    ),
                    _cashierDetail(
                      'Discount',
                      'PHP ${_cashierMoney(data['discountAmount'])} (${data['discountType'] ?? '-'})',
                    ),
                    _cashierDetail(
                      'Total paid',
                      'PHP ${_cashierMoney(data['totalAmount'])}',
                    ),
                    const Divider(),
                    const Text(
                      'Purchased items',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    for (final item in snapshot.data!.docs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.data()['productName']?.toString() ?? 'Product',
                        ),
                        subtitle: Text(
                          '${item.data()['quantity'] ?? 0} ${item.data()['unit'] ?? 'box'}',
                        ),
                        trailing: Text(
                          'PHP ${_cashierMoney(item.data()['lineTotal'])}',
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _CashierSummaryLine extends StatelessWidget {
  const _CashierSummaryLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

Widget _cashierDetail(String label, dynamic value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      Text(value?.toString() ?? '-'),
    ],
  ),
);

String _cashierDate(dynamic value) {
  final date = value is Timestamp
      ? value.toDate()
      : DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return 'Date not recorded';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _CashierEmptyState extends StatelessWidget {
  const _CashierEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

double _cashierNumber(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _cashierMoney(dynamic value) {
  final number = _cashierNumber(value);
  return number == number.roundToDouble()
      ? number.toInt().toString()
      : number.toStringAsFixed(2);
}
