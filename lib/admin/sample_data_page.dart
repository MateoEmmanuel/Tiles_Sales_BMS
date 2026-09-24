import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class SampleDataPage extends StatefulWidget {
  const SampleDataPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<SampleDataPage> createState() => _SampleDataPageState();
}

class _SampleDataPageState extends State<SampleDataPage> {
  final _firebaseService = FirebaseService();
  bool _running = false;
  String _status = 'Ready to generate sample data.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              surfaceTintColor: Theme.of(context).scaffoldBackgroundColor,
              title: const Text('Sample data generator'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Development data only',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This hidden page creates 25 products, 5 suppliers with 5 products each, inventory, stock movements, and 600 sales across the last six months.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 20),
                    Text(_status),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _running ? null : _confirmAndGenerate,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(
                          _running ? 'Generating...' : 'Generate sample data',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Existing records are not deleted. Running this more than once adds another sample set.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndGenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate sample data?'),
        content: const Text(
          'This will add 25 products, 5 suppliers, inventory movements, and 600 transactions. Existing data will remain. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _generate();
  }

  Future<void> _generate() async {
    if (!_firebaseService.isInitialized) {
      setState(() => _status = 'Firebase is not initialized.');
      return;
    }
    setState(() {
      _running = true;
      _status = 'Preparing products and suppliers...';
    });
    try {
      final firestore = _firebaseService.getFirestore();
      final products = <DocumentReference<Map<String, dynamic>>>[];
      final suppliers = <DocumentReference<Map<String, dynamic>>>[];
      final operations = <_WriteOperation>[];
      final now = DateTime.now();

      for (var index = 0; index < 5; index++) {
        final supplier = firestore
            .collection('suppliers')
            .doc('sample_supplier_${index + 1}');
        suppliers.add(supplier);
        operations.add(
          _WriteOperation.set(supplier, {
            'companyName': 'Sample Tile Supplier ${index + 1}',
            'contactPerson': 'Sample Contact ${index + 1}',
            'phoneNumber': '09${(100000000 + index).toString()}',
            'email': 'supplier${index + 1}@sample.test',
            'paymentTerms': 'Cash on delivery',
            'notes': 'Generated development supplier',
            'status': 'active',
            'sampleData': true,
            'createdAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
          }),
        );
      }

      for (var index = 0; index < 25; index++) {
        final supplierIndex = index ~/ 5;
        final product = firestore
            .collection('products')
            .doc('sample_product_${index + 1}');
        products.add(product);
        final price = 420 + (index % 8) * 85.0;
        operations.add(
          _WriteOperation.set(product, {
            'productName': 'Sample Tile ${index + 1}',
            'brand': 'Sample Brand ${supplierIndex + 1}',
            'design': ['Marble', 'Stone', 'Wood', 'Concrete'][index % 4],
            'color': ['White', 'Grey', 'Beige', 'Charcoal'][index % 4],
            'size': ['30x30 cm', '40x40 cm', '60x60 cm'][index % 3],
            'thickness': 8 + (index % 3),
            'finish': ['Glossy', 'Matte', 'Textured'][index % 3],
            'piecesPerBox': 4 + (index % 3) * 2,
            'coveragePerBox': 1.44 + (index % 3) * 0.36,
            'pricePerBox': price,
            'pricePerSqm': price / 1.44,
            'pricePerSqft': price / 15.5,
            'reorderPoint': 80,
            'maximumStock': 2500,
            'supplierId': suppliers[supplierIndex],
            'supplierName': 'Sample Tile Supplier ${supplierIndex + 1}',
            'status': 'active',
            'sampleData': true,
            'createdAt': Timestamp.fromDate(now),
            'updatedAt': Timestamp.fromDate(now),
          }),
        );
        final inventory = firestore
            .collection('inventory')
            .doc('sample_inventory_${index + 1}');
        operations.add(
          _WriteOperation.set(inventory, {
            'productId': product,
            'product_dID': product.id,
            'quantityOnHand': 2200,
            'current_stock': 2200,
            'availableQuantity': 2200,
            'allocatedQuantity': 0,
            'unit': 'box',
            'reorderPoint': 80,
            'stockStatus': 'in_stock',
            'sampleData': true,
            'lastUpdatedAt': Timestamp.fromDate(now),
          }),
        );
      }

      for (var index = 0; index < 5; index++) {
        final productIds = [
          for (var offset = 0; offset < 5; offset++)
            products[index * 5 + offset],
        ];
        operations.add(
          _WriteOperation.update(suppliers[index], {
            'productIds': productIds,
            'productCount': 5,
          }),
        );
      }

      final supplierUpdates = operations
          .where((operation) => operation.fields != null)
          .toList();
      await _commitOperations(
        firestore,
        operations.where((operation) => operation.fields == null).toList(),
      );
      await _commitOperations(firestore, supplierUpdates);
      await _generateMovementsAndSales(firestore, products, suppliers, now);
      if (mounted) {
        setState(
          () => _status =
              'Complete: 25 products, 5 suppliers, and 600 sales generated.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Generation failed: $error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _generateMovementsAndSales(
    FirebaseFirestore firestore,
    List<DocumentReference<Map<String, dynamic>>> products,
    List<DocumentReference<Map<String, dynamic>>> suppliers,
    DateTime now,
  ) async {
    final operations = <_WriteOperation>[];
    for (var productIndex = 0; productIndex < products.length; productIndex++) {
      final supplier = suppliers[productIndex ~/ 5];
      operations.add(
        _WriteOperation.set(
          firestore
              .collection('stock_movements')
              .doc('sample_restock_${productIndex + 1}'),
          {
            'productId': products[productIndex],
            'movementType': 'restock',
            'quantity': 2200,
            'unit': 'box',
            'previousQuantity': 0,
            'newQuantity': 2200,
            'supplierId': supplier,
            'reason': 'Initial sample stock',
            'movementDate': Timestamp.fromDate(
              now.subtract(const Duration(days: 180)),
            ),
            'createdAt': Timestamp.fromDate(now),
            'sampleData': true,
          },
        ),
      );
    }

    var transactionNumber = 0;
    for (var monthOffset = 5; monthOffset >= 0; monthOffset--) {
      final monthStart = DateTime(now.year, now.month - monthOffset, 8);
      for (
        var transactionInMonth = 0;
        transactionInMonth < 100;
        transactionInMonth++
      ) {
        final productIndex =
            (transactionNumber * 7 + transactionInMonth) % products.length;
        final product = products[productIndex];
        final quantity = 1 + ((transactionNumber + transactionInMonth) % 4);
        final unitPrice = 420 + (productIndex % 8) * 85.0;
        final subtotal = unitPrice * quantity;
        final discount = transactionNumber % 10 == 0 ? subtotal * 0.05 : 0.0;
        final total = subtotal - discount;
        final saleDate = monthStart.add(
          Duration(
            days: transactionInMonth % 20,
            hours: transactionInMonth % 9,
          ),
        );
        final sale = firestore
            .collection('sales')
            .doc('sample_sale_${transactionNumber + 1}');
        operations.add(
          _WriteOperation.set(sale, {
            'salesId': sale.id,
            'customerName': 'Sample Customer ${transactionNumber + 1}',
            'saleDate': Timestamp.fromDate(saleDate),
            'subtotal': subtotal,
            'discountAmount': discount,
            'discountType': discount == 0 ? 'amount' : 'percent',
            'discountValue': discount == 0 ? 0 : 5,
            'totalAmount': total,
            'amountPaid': total,
            'changeAmount': 0,
            'paymentStatus': 'paid',
            'saleStatus': 'completed',
            'sampleData': true,
          }),
        );
        operations.add(
          _WriteOperation.set(sale.collection('items').doc(product.id), {
            'productId': product,
            'productName': 'Sample Tile ${productIndex + 1}',
            'quantity': quantity,
            'unit': 'box',
            'unitPrice': unitPrice,
            'lineTotal': subtotal,
          }),
        );
        operations.add(
          _WriteOperation.set(
            firestore
                .collection('stock_movements')
                .doc('sample_sale_movement_${transactionNumber + 1}'),
            {
              'productId': product,
              'movementType': 'sale',
              'quantity': quantity,
              'unit': 'box',
              'previousQuantity': 2200,
              'newQuantity': 2200 - quantity,
              'relatedSaleId': sale,
              'reason': 'Sample cashier sale',
              'movementDate': Timestamp.fromDate(saleDate),
              'createdAt': Timestamp.fromDate(saleDate),
              'sampleData': true,
            },
          ),
        );
        transactionNumber++;
        if (operations.length >= 360) {
          await _commitOperations(firestore, operations);
          operations.clear();
          if (mounted) {
            setState(
              () => _status =
                  'Generated $transactionNumber of 600 transactions...',
            );
          }
        }
      }
    }
    if (operations.isNotEmpty) await _commitOperations(firestore, operations);
  }

  Future<void> _commitOperations(
    FirebaseFirestore firestore,
    List<_WriteOperation> operations,
  ) async {
    for (var start = 0; start < operations.length; start += 400) {
      final end = (start + 400).clamp(0, operations.length);
      final batch = firestore.batch();
      for (final operation in operations.sublist(start, end)) {
        if (operation.data == null) {
          batch.update(operation.reference, operation.fields!);
        } else {
          batch.set(operation.reference, operation.data!);
        }
      }
      await batch.commit();
    }
  }
}

class _WriteOperation {
  const _WriteOperation._(this.reference, this.data, this.fields);

  factory _WriteOperation.set(
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> data,
  ) => _WriteOperation._(reference, data, null);

  factory _WriteOperation.update(
    DocumentReference<Map<String, dynamic>> reference,
    Map<String, dynamic> fields,
  ) => _WriteOperation._(reference, null, fields);

  final DocumentReference<Map<String, dynamic>> reference;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? fields;
}
