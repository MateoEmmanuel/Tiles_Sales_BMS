import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

String _printDateLabel(dynamic value) {
  final date = value is Timestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : DateTime.tryParse('$value');
  if (date == null) return '-';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

Future<void> showDamagePrintDialog(
  BuildContext context,
  List<DocumentSnapshot<Map<String, dynamic>>> movements,
  List<DocumentSnapshot<Map<String, dynamic>>> products,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _DamagePrintDialog(movements: movements, products: products),
  );
}

Future<void> showInventoryPrintDialog(
  BuildContext context,
  List<DocumentSnapshot<Map<String, dynamic>>> products,
  Map<String, Map<String, dynamic>> inventory,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _InventoryPrintDialog(products: products, inventory: inventory),
  );
}

Future<void> showSupplierPrintDialog(
  BuildContext context,
  List<DocumentSnapshot<Map<String, dynamic>>> suppliers,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _SupplierPrintDialog(suppliers: suppliers),
  );
}

abstract class _OfficePrintDialogState<T extends StatefulWidget>
    extends State<T> {
  String paperSize = 'A4';
  String orientation = 'portrait';
  String margin = 'standard';

  PdfPageFormat get pageFormat {
    final base = switch (paperSize) {
      'Letter' => PdfPageFormat.letter,
      'Legal' => PdfPageFormat.legal,
      _ => PdfPageFormat.a4,
    };
    final oriented = orientation == 'landscape' ? base.landscape : base;
    final value = margin == 'narrow'
        ? 24.0
        : margin == 'wide'
        ? 64.0
        : 40.0;
    return oriented.copyWith(
      marginTop: value,
      marginBottom: value,
      marginLeft: value,
      marginRight: value,
    );
  }

  Widget settings() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _dropdown('Paper size', paperSize, const [
              'A4',
              'Letter',
              'Legal',
            ], (value) => setState(() => paperSize = value)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _dropdown(
              'Orientation',
              orientation,
              const ['portrait', 'landscape'],
              (value) => setState(() => orientation = value),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _dropdown('Margins', margin, const [
        'narrow',
        'standard',
        'wide',
      ], (value) => setState(() => margin = value)),
    ],
  );

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final item in values)
        DropdownMenuItem(
          value: item,
          child: Text(item[0].toUpperCase() + item.substring(1)),
        ),
    ],
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );

  Future<void> printPdf(Uint8List bytes) =>
      Printing.layoutPdf(onLayout: (_) async => bytes);
  Future<void> downloadPdf(Uint8List bytes, String name) =>
      Printing.sharePdf(bytes: bytes, filename: name);
}

class _DamagePrintDialog extends StatefulWidget {
  const _DamagePrintDialog({required this.movements, required this.products});
  final List<DocumentSnapshot<Map<String, dynamic>>> movements;
  final List<DocumentSnapshot<Map<String, dynamic>>> products;
  @override
  State<_DamagePrintDialog> createState() => _DamagePrintDialogState();
}

class _DamagePrintDialogState
    extends _OfficePrintDialogState<_DamagePrintDialog> {
  String range = 'month';
  DateTimeRange? customRange;

  String _productName(dynamic value) {
    final id = value is DocumentReference ? value.id : value?.toString();
    if (id == null) return 'Product';
    for (final product in widget.products) {
      if (product.id == id) {
        return product.data()?['productName']?.toString() ?? 'Product';
      }
    }
    return id;
  }

  List<Map<String, dynamic>> get rows {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;
    if (range == 'month') start = DateTime(now.year, now.month);
    if (range == 'year') start = DateTime(now.year);
    if (range == 'custom' && customRange != null) {
      start = customRange!.start;
      end = DateTime(
        customRange!.end.year,
        customRange!.end.month,
        customRange!.end.day + 1,
      );
    }
    return widget.movements.map((item) => item.data() ?? {}).where((data) {
      if (data['movementType']?.toString() != 'damaged') return false;
      final value = data['movementDate'];
      final date = value is Timestamp
          ? value.toDate()
          : DateTime.tryParse('$value');
      return start == null ||
          (date != null &&
              !date.isBefore(start) &&
              (end == null || date.isBefore(end)));
    }).toList();
  }

  @override
  Widget build(BuildContext context) => _dialog(
    context,
    'Print damage history',
    '${rows.length} damage records selected',
    [_dropdownRange(context), const SizedBox(height: 14), settings()],
    rows.isEmpty
        ? null
        : () async {
            final bytes = await _pdf();
            await printPdf(bytes);
          },
    rows.isEmpty
        ? null
        : () async {
            final bytes = await _pdf();
            await downloadPdf(bytes, 'damage-history.pdf');
          },
  );

  Widget _dropdownRange(BuildContext context) =>
      DropdownButtonFormField<String>(
        initialValue: range,
        decoration: const InputDecoration(
          labelText: 'Date range',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'month', child: Text('This month')),
          DropdownMenuItem(value: 'year', child: Text('This year')),
          DropdownMenuItem(value: 'custom', child: Text('Custom range')),
          DropdownMenuItem(value: 'all', child: Text('All history')),
        ],
        onChanged: (value) async {
          if (value == null) return;
          if (value == 'custom') {
            final selected = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
              initialDateRange: customRange,
              helpText: 'Select damage range',
              cancelText: 'Cancel',
              confirmText: 'Apply range',
            );
            if (selected == null) return;
            setState(() => customRange = selected);
          }
          setState(() => range = value);
        },
      );

  Future<Uint8List> _pdf() async => _tablePdf(
    title: 'Damage history',
    subtitle: range == 'month'
        ? 'This month'
        : range == 'year'
        ? 'This year'
        : range == 'custom' && customRange != null
        ? '${customRange!.start.toIso8601String().split('T').first} - ${customRange!.end.toIso8601String().split('T').first}'
        : 'All history',
    headers: const ['Product', 'Quantity', 'Reason', 'Date'],
    rows: rows
        .map(
          (data) => [
            _productName(data['productName'] ?? data['productId']),
            '${data['quantity'] ?? 0}',
            '${data['reason'] ?? '-'}',
            _printDateLabel(data['movementDate']),
          ],
        )
        .toList(),
    format: pageFormat,
  );
}

class _InventoryPrintDialog extends StatefulWidget {
  const _InventoryPrintDialog({
    required this.products,
    required this.inventory,
  });
  final List<DocumentSnapshot<Map<String, dynamic>>> products;
  final Map<String, Map<String, dynamic>> inventory;
  @override
  State<_InventoryPrintDialog> createState() => _InventoryPrintDialogState();
}

class _InventoryPrintDialogState
    extends _OfficePrintDialogState<_InventoryPrintDialog> {
  String detail = 'semi';
  @override
  Widget build(BuildContext context) => _dialog(
    context,
    'Print stock list',
    '${widget.products.length} products selected',
    [
      DropdownButtonFormField<String>(
        initialValue: detail,
        decoration: const InputDecoration(
          labelText: 'Product details',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'name', child: Text('Name and stock')),
          DropdownMenuItem(
            value: 'semi',
            child: Text('Name, stock, and status'),
          ),
          DropdownMenuItem(value: 'full', child: Text('Full details')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => detail = value);
        },
      ),
      const SizedBox(height: 14),
      settings(),
    ],
    () async {
      final bytes = await _pdf();
      await printPdf(bytes);
    },
    () async {
      final bytes = await _pdf();
      await downloadPdf(bytes, 'stock-list.pdf');
    },
  );

  Future<Uint8List> _pdf() async => _tablePdf(
    title: 'Stock list and status',
    subtitle: detail == 'name'
        ? 'Name and stock'
        : detail == 'full'
        ? 'Full product details'
        : 'Name, stock, and status',
    headers: detail == 'name'
        ? const ['Product', 'Stock']
        : detail == 'full'
        ? const ['Product', 'Brand', 'Size', 'Price', 'Stock', 'Status']
        : const ['Product', 'Stock', 'Status'],
    rows: widget.products.map((product) {
      final data = product.data() ?? {};
      final stock =
          widget.inventory[product.id]?['quantityOnHand'] ??
          widget.inventory[product.id]?['current_stock'] ??
          0;
      final status = stock <= 0
          ? 'Out of stock'
          : stock <= (data['reorderPoint'] ?? 0)
          ? 'Low stock'
          : 'In stock';
      if (detail == 'name') {
        return ['${data['productName'] ?? 'Product'}', '$stock'];
      }
      if (detail == 'full') {
        return [
          '${data['productName'] ?? 'Product'}',
          '${data['brand'] ?? '-'}',
          '${data['size'] ?? '-'}',
          'PHP ${data['pricePerBox'] ?? '-'}',
          '$stock',
          status,
        ];
      }
      return ['${data['productName'] ?? 'Product'}', '$stock', status];
    }).toList(),
    format: pageFormat,
  );
}

class _SupplierPrintDialog extends StatefulWidget {
  const _SupplierPrintDialog({required this.suppliers});
  final List<DocumentSnapshot<Map<String, dynamic>>> suppliers;
  @override
  State<_SupplierPrintDialog> createState() => _SupplierPrintDialogState();
}

class _SupplierPrintDialogState
    extends _OfficePrintDialogState<_SupplierPrintDialog> {
  String detail = 'semi';
  @override
  Widget build(BuildContext context) => _dialog(
    context,
    'Print supplier list',
    '${widget.suppliers.length} suppliers selected',
    [
      DropdownButtonFormField<String>(
        initialValue: detail,
        decoration: const InputDecoration(
          labelText: 'Supplier details',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'name', child: Text('Company name only')),
          DropdownMenuItem(value: 'semi', child: Text('Name and contact')),
          DropdownMenuItem(value: 'full', child: Text('Full supplier details')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => detail = value);
        },
      ),
      const SizedBox(height: 14),
      settings(),
    ],
    () async {
      final bytes = await _pdf();
      await printPdf(bytes);
    },
    () async {
      final bytes = await _pdf();
      await downloadPdf(bytes, 'supplier-list.pdf');
    },
  );

  Future<Uint8List> _pdf() async => _tablePdf(
    title: 'Supplier list',
    subtitle: detail == 'name'
        ? 'Company names'
        : detail == 'full'
        ? 'Full supplier details'
        : 'Company names and contacts',
    headers: detail == 'name'
        ? const ['Company']
        : detail == 'full'
        ? const ['Company', 'Contact', 'Phone', 'Email', 'Terms', 'Status']
        : const ['Company', 'Contact', 'Phone'],
    rows: widget.suppliers.map((supplier) {
      final data = supplier.data() ?? {};
      if (detail == 'name') return ['${data['companyName'] ?? 'Supplier'}'];
      if (detail == 'full') {
        return [
          '${data['companyName'] ?? 'Supplier'}',
          '${data['contactPerson'] ?? '-'}',
          '${data['phoneNumber'] ?? '-'}',
          '${data['email'] ?? '-'}',
          '${data['paymentTerms'] ?? '-'}',
          '${data['status'] ?? 'active'}',
        ];
      }
      return [
        '${data['companyName'] ?? 'Supplier'}',
        '${data['contactPerson'] ?? '-'}',
        '${data['phoneNumber'] ?? '-'}',
      ];
    }).toList(),
    format: pageFormat,
  );
}

Widget _dialog(
  BuildContext context,
  String title,
  String subtitle,
  List<Widget> children,
  Future<void> Function()? onPrint,
  Future<void> Function()? onDownload,
) => AlertDialog(
  title: Text(title),
  content: SizedBox(
    width: 520,
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    ),
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Cancel'),
    ),
    OutlinedButton.icon(
      onPressed: onDownload,
      icon: const Icon(Icons.download_outlined),
      label: const Text('Download'),
    ),
    FilledButton.icon(
      onPressed: onPrint,
      icon: const Icon(Icons.print_outlined),
      label: const Text('Print'),
    ),
  ],
);

Future<Uint8List> _tablePdf({
  required String title,
  required String subtitle,
  required List<String> headers,
  required List<List<String>> rows,
  required PdfPageFormat format,
}) async {
  final document = pw.Document();
  document.addPage(
    pw.MultiPage(
      pageFormat: format,
      build: (_) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(subtitle, style: const pw.TextStyle(fontSize: 16)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 10),
        ),
      ],
    ),
  );
  return Uint8List.fromList(await document.save());
}
