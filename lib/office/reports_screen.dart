import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/firebase_service.dart';
import 'office_print_dialogs.dart';

Future<Uint8List> _preparePdf(
  BuildContext context,
  Future<Uint8List> Function() build,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 16),
          Text('Preparing report...'),
        ],
      ),
    ),
  );
  try {
    return await build();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _firebaseService = FirebaseService();
  int _section = 0;
  String _searchTerm = '';
  String _period = 'day';

  static const _sections = [
    ('Summary', Icons.dashboard_outlined),
    ('Sales', Icons.point_of_sale_outlined),
    ('Inventory & movement', Icons.inventory_2_outlined),
    ('Product damage', Icons.warning_amber_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    if (!_firebaseService.isInitialized) {
      return const Center(child: Text('Firebase is not initialized'));
    }

    final firestore = _firebaseService.getFirestore();
    return Column(
      children: [
        _ReportNavigation(
          selected: _section,
          sections: _sections,
          onSelected: (value) => setState(() => _section = value),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: firestore.collection('sales').snapshots(),
            builder: (context, salesSnapshot) {
              if (salesSnapshot.hasError) {
                return _error(
                  'Could not load sales reports.\n${salesSnapshot.error}',
                );
              }
              if (!salesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: firestore.collection('products').snapshots(),
                builder: (context, productsSnapshot) {
                  if (productsSnapshot.hasError) {
                    return _error(
                      'Could not load product reports.\n${productsSnapshot.error}',
                    );
                  }
                  if (!productsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: firestore.collection('inventory').snapshots(),
                    builder: (context, inventorySnapshot) {
                      if (inventorySnapshot.hasError) {
                        return _error(
                          'Could not load inventory reports.\n${inventorySnapshot.error}',
                        );
                      }
                      if (!inventorySnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: firestore
                            .collection('stock_movements')
                            .snapshots(),
                        builder: (context, movementSnapshot) {
                          if (movementSnapshot.hasError) {
                            return _error(
                              'Could not load movement reports.\n${movementSnapshot.error}',
                            );
                          }
                          if (!movementSnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final data = _ReportData(
                            sales: salesSnapshot.data!.docs,
                            products: productsSnapshot.data!.docs,
                            inventory: inventorySnapshot.data!.docs,
                            movements: movementSnapshot.data!.docs,
                          );
                          return _buildSection(data);
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSection(_ReportData data) {
    switch (_section) {
      case 1:
        return _SalesReport(
          data: data,
          period: _period,
          onPeriodChanged: (value) => setState(() => _period = value),
        );
      case 2:
        return _InventoryReport(
          data: data,
          searchTerm: _searchTerm,
          onSearch: (value) => setState(() => _searchTerm = value),
        );
      case 3:
        return _MovementReport(
          data: data,
          searchTerm: _searchTerm,
          onSearch: (value) => setState(() => _searchTerm = value),
        );
      default:
        return _SummaryReport(
          data: data,
          onOpenSection: (value) => setState(() => _section = value),
        );
    }
  }
}

class _ReportNavigation extends StatelessWidget {
  const _ReportNavigation({
    required this.selected,
    required this.sections,
    required this.onSelected,
  });

  final int selected;
  final List<(String, IconData)> sections;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 11),
            child: Text(
              'Reports',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ),
          for (var index = 0; index < sections.length; index++)
            TextButton.icon(
              onPressed: () => onSelected(index),
              icon: Icon(sections[index].$2, size: 17),
              label: Text(sections[index].$1),
              style: TextButton.styleFrom(
                foregroundColor: selected == index
                    ? Colors.indigo
                    : Colors.grey.shade700,
                textStyle: TextStyle(
                  fontWeight: selected == index
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportData {
  const _ReportData({
    required this.sales,
    required this.products,
    required this.inventory,
    required this.movements,
  });

  final List<DocumentSnapshot<Map<String, dynamic>>> sales;
  final List<DocumentSnapshot<Map<String, dynamic>>> products;
  final List<DocumentSnapshot<Map<String, dynamic>>> inventory;
  final List<DocumentSnapshot<Map<String, dynamic>>> movements;

  double get income => sales.fold(
    0,
    (total, sale) => total + _number(sale.data()?['totalAmount']),
  );
  double get collected => sales.fold(
    0,
    (total, sale) => total + _number(sale.data()?['amountPaid']),
  );
  double get stock => inventory.fold(
    0,
    (total, item) =>
        total +
        _number(
          item.data()?['quantityOnHand'] ?? item.data()?['current_stock'],
        ),
  );
}

class _SummaryReport extends StatelessWidget {
  const _SummaryReport({required this.data, required this.onOpenSection});

  final _ReportData data;
  final ValueChanged<int> onOpenSection;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      children: [
        const _ReportIntro(
          title: 'Business report summary',
          subtitle:
              'A read-only view of the business records that drive your decisions.',
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ReportMetric(
              label: 'Sales income',
              value: 'PHP ${_money(data.income)}',
              icon: Icons.trending_up,
              color: Colors.green,
            ),
            _ReportMetric(
              label: 'Collected',
              value: 'PHP ${_money(data.collected)}',
              icon: Icons.payments_outlined,
              color: Colors.indigo,
            ),
            _ReportMetric(
              label: 'Stock quantity',
              value: _money(data.stock),
              icon: Icons.inventory_2_outlined,
              color: Colors.teal,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showSalesPrintDialog(context, data.sales),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print sales report'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showTrendPrintDialog(context, data.sales),
              icon: const Icon(Icons.show_chart_outlined),
              label: const Text('Print sales trends'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  showDamagePrintDialog(context, data.movements, data.products),
              icon: const Icon(Icons.warning_amber_outlined),
              label: const Text('Print damage history'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Daily total sales - last 30 days',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _ReportPanel(child: _DailySalesTrendChart(sales: data.sales)),
        const SizedBox(height: 24),
        const Text(
          'Product sales trends and restock coverage',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _SummaryInventoryInsights(data: data),
        const SizedBox(height: 24),
        const Text(
          'Inventory movement overview',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _ReportPanel(
          child: _InventoryMovementPieChart(
            inventory: data.inventory,
            movements: data.movements,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Report modules',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              'Source records remain editable in their operational modules.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ReportModule(
          title: 'Sales reports',
          description: 'Income, payments, and transaction trends.',
          icon: Icons.point_of_sale_outlined,
          onTap: () => onOpenSection(1),
        ),
        _ReportModule(
          title: 'Inventory & movement reports',
          description:
              'Current stock, reorder thresholds, and outgoing sales rate.',
          icon: Icons.inventory_2_outlined,
          onTap: () => onOpenSection(2),
        ),
        _ReportModule(
          title: 'Product damage reports',
          description: 'Damaged stock incidents, quantities, and reasons.',
          icon: Icons.warning_amber_outlined,
          onTap: () => onOpenSection(3),
        ),
      ],
    );
  }
}

class _SalesReport extends StatefulWidget {
  const _SalesReport({
    required this.data,
    required this.period,
    required this.onPeriodChanged,
  });

  final _ReportData data;
  final String period;
  final ValueChanged<String> onPeriodChanged;

  @override
  State<_SalesReport> createState() => _SalesReportState();
}

class _SalesReportState extends State<_SalesReport> {
  bool _showTrends = false;
  String _trendPeriod = 'month';

  @override
  Widget build(BuildContext context) {
    if (_showTrends) {
      return _SalesTrends(
        data: widget.data,
        period: _trendPeriod,
        onPeriodChanged: (value) => setState(() => _trendPeriod = value),
        onBack: () => setState(() => _showTrends = false),
      );
    }

    final filtered = widget.data.sales
        .where((sale) => _matchesPeriod(sale.data()?['saleDate'], period))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      children: [
        const _ReportIntro(
          title: 'Sales report',
          subtitle: 'Income, collection, and transaction history.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text('Period', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: widget.period,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'day', child: Text('Today')),
                  DropdownMenuItem(value: 'month', child: Text('This month')),
                  DropdownMenuItem(value: 'year', child: Text('This year')),
                ],
                onChanged: (value) {
                  if (value != null) widget.onPeriodChanged(value);
                },
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showTrends = true),
              icon: const Icon(Icons.show_chart_outlined),
              label: const Text('Trends'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ReportPanel(
          child: _IncomeChart(
            sales: filtered,
            period: widget.period == 'year' ? 'year' : 'month',
          ),
        ),
        const SizedBox(height: 20),
        _ReportTableHeader(
          labels: const ['Customer', 'Receipt', 'Date', 'Total'],
        ),
        for (final sale in filtered) _SalesReportRow(sale: sale),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No sales records')),
          ),
      ],
    );
  }

  String get period => widget.period;
}

class _SalesTrends extends StatelessWidget {
  const _SalesTrends({
    required this.data,
    required this.period,
    required this.onPeriodChanged,
    required this.onBack,
  });

  final _ReportData data;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final totals = _salesTrendTotals(data.sales, period);
    final ascending = totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final ranked = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: 'Back to sales',
              icon: const Icon(Icons.arrow_back),
            ),
            const Expanded(
              child: _ReportIntro(
                title: 'Sales trends',
                subtitle:
                    'Compare sales movement from month to month or year to year.',
              ),
            ),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: period,
                decoration: const InputDecoration(
                  labelText: 'Trend period',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'month', child: Text('Monthly')),
                  DropdownMenuItem(value: 'year', child: Text('Yearly')),
                ],
                onChanged: (value) {
                  if (value != null) onPeriodChanged(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ReportPanel(
          child: ascending.isEmpty
              ? const SizedBox(
                  height: 190,
                  child: Center(child: Text('No sales trend data')),
                )
              : _TrendLineChart(
                  values: [for (final entry in ascending) entry.value],
                  labels: [
                    for (final entry in ascending) _trendLabel(entry.key),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Highest sales trends',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _ReportTableHeader(labels: const ['Period', 'Total sales']),
        for (final entry in ranked)
          ListTile(
            title: Text(_trendLabel(entry.key)),
            trailing: Text(
              'PHP ${_money(entry.value)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        if (ranked.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No sales trend data')),
          ),
      ],
    );
  }
}

Map<DateTime, double> _salesTrendTotals(
  List<DocumentSnapshot<Map<String, dynamic>>> sales,
  String period,
) {
  final totals = <DateTime, double>{};
  for (final sale in sales) {
    final date = _date(sale.data()?['saleDate']);
    if (date == null) continue;
    final bucket = period == 'year'
        ? DateTime(date.year)
        : DateTime(date.year, date.month);
    totals[bucket] =
        (totals[bucket] ?? 0) + _number(sale.data()?['totalAmount']);
  }
  return totals;
}

void _showSalesPrintDialog(
  BuildContext context,
  List<DocumentSnapshot<Map<String, dynamic>>> sales,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _SalesPrintDialog(sales: sales),
  );
}

void _showTrendPrintDialog(
  BuildContext context,
  List<DocumentSnapshot<Map<String, dynamic>>> sales,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _TrendPrintDialog(sales: sales, period: 'month'),
  );
}

class _TrendPrintDialog extends StatefulWidget {
  const _TrendPrintDialog({required this.sales, required this.period});

  final List<DocumentSnapshot<Map<String, dynamic>>> sales;
  final String period;

  @override
  State<_TrendPrintDialog> createState() => _TrendPrintDialogState();
}

class _TrendPrintDialogState extends State<_TrendPrintDialog> {
  bool _includeChart = true;
  bool _includeRanking = true;
  String _paperSize = 'A4';
  String _orientation = 'portrait';
  String _margin = 'standard';

  PdfPageFormat get _pageFormat {
    final base = switch (_paperSize) {
      'Letter' => PdfPageFormat.letter,
      'Legal' => PdfPageFormat.legal,
      _ => PdfPageFormat.a4,
    };
    final oriented = _orientation == 'landscape' ? base.landscape : base;
    final margin = switch (_margin) {
      'narrow' => 24.0,
      'wide' => 64.0,
      _ => 40.0,
    };
    return oriented.copyWith(
      marginTop: margin,
      marginBottom: margin,
      marginLeft: margin,
      marginRight: margin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Print sales trends'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.period == 'year' ? 'Yearly' : 'Monthly'} trend report',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _includeChart,
                title: const Text('Trend chart'),
                onChanged: (value) =>
                    setState(() => _includeChart = value ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _includeRanking,
                title: const Text('Highest-to-lowest listing'),
                onChanged: (value) =>
                    setState(() => _includeRanking = value ?? false),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _paperSize,
                      decoration: const InputDecoration(
                        labelText: 'Paper size',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'A4', child: Text('A4')),
                        DropdownMenuItem(
                          value: 'Letter',
                          child: Text('Letter'),
                        ),
                        DropdownMenuItem(value: 'Legal', child: Text('Legal')),
                      ],
                      onChanged: (value) => setState(() => _paperSize = value!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _orientation,
                      decoration: const InputDecoration(
                        labelText: 'Orientation',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'portrait',
                          child: Text('Portrait'),
                        ),
                        DropdownMenuItem(
                          value: 'landscape',
                          child: Text('Landscape'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _orientation = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _margin,
                decoration: const InputDecoration(
                  labelText: 'Margins',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'narrow', child: Text('Narrow')),
                  DropdownMenuItem(value: 'standard', child: Text('Standard')),
                  DropdownMenuItem(value: 'wide', child: Text('Wide')),
                ],
                onChanged: (value) => setState(() => _margin = value!),
              ),
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
          onPressed: widget.sales.isEmpty ? null : _download,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Download'),
        ),
        FilledButton.icon(
          onPressed: widget.sales.isEmpty ? null : _print,
          icon: const Icon(Icons.print_outlined),
          label: const Text('Print'),
        ),
      ],
    );
  }

  Future<Uint8List> _buildPdf() async {
    final document = pw.Document();
    final series = await _productTrendSeries();
    final ranked = series.toList()..sort((a, b) => b.value.compareTo(a.value));
    document.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        build: (context) => [
          pw.Text(
            'Sales trends',
            style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${widget.period == 'year' ? 'Yearly' : 'Monthly'} trend report',
            style: const pw.TextStyle(fontSize: 20),
          ),
          if (_includeChart) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Trend chart',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            if (series.isEmpty)
              pw.Text('No product trend data available')
            else ...[
              _pdfProductTrendChart(series),
              pw.SizedBox(height: 8),
              for (var index = 0; index < series.length; index++)
                _pdfProductTrendRow(series[index], index),
            ],
          ],
          if (_includeRanking) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'Highest-to-lowest listing',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.TableHelper.fromTextArray(
              headers: const ['Product', 'Total sales'],
              cellStyle: const pw.TextStyle(fontSize: 16),
              data: [
                for (final entry in ranked)
                  [entry.name, 'PHP ${_money(entry.value)}'],
              ],
            ),
          ],
        ],
      ),
    );
    return Uint8List.fromList(await document.save());
  }

  Future<List<_ProductTrendSeries>> _productTrendSeries() async {
    final byProduct = <String, _ProductTrendSeries>{};
    for (final sale in widget.sales) {
      final saleDate = _date(sale.data()?['saleDate']);
      if (saleDate == null) continue;
      final bucket = widget.period == 'year'
          ? DateTime(saleDate.year)
          : DateTime(saleDate.year, saleDate.month);
      final items = await sale.reference.collection('items').get();
      for (final item in items.docs) {
        final data = item.data();
        final productId = _referenceId(data['productId'] ?? item.id);
        final productName = data['productName']?.toString() ?? productId;
        final product = byProduct.putIfAbsent(
          productId,
          () => _ProductTrendSeries(name: productName),
        );
        product.points[bucket] =
            (product.points[bucket] ?? 0) +
            _number(data['lineTotal'] ?? data['quantity']);
      }
    }
    return byProduct.values.where((series) => series.value > 0).toList();
  }

  pw.Widget _pdfProductTrendChart(List<_ProductTrendSeries> series) {
    final buckets = <DateTime>{
      for (final product in series) ...product.points.keys,
    }.toList()..sort();
    final maximum = series
        .expand((product) => product.points.values)
        .fold<double>(0, (current, value) => value > current ? value : current);
    if (buckets.isEmpty || maximum == 0) {
      return pw.Text('No product trend data available');
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(
          height: 220,
          child: pw.CustomPaint(
            painter: (canvas, size) {
              canvas.setLineWidth(1);
              canvas.setStrokeColor(PdfColors.grey400);
              for (var tick = 0; tick <= 4; tick++) {
                final y = size.y * tick / 4;
                canvas.drawLine(0, y, size.x, y);
              }
              for (var index = 0; index < series.length; index++) {
                final product = series[index];
                final color = _pdfTrendColors[index % _pdfTrendColors.length];
                canvas.setStrokeColor(color);
                canvas.setLineWidth(2.2);
                final points = <PdfPoint>[];
                for (
                  var bucketIndex = 0;
                  bucketIndex < buckets.length;
                  bucketIndex++
                ) {
                  final value = product.points[buckets[bucketIndex]] ?? 0;
                  points.add(
                    PdfPoint(
                      buckets.length == 1
                          ? size.x / 2
                          : size.x * bucketIndex / (buckets.length - 1),
                      size.y - size.y * value / maximum,
                    ),
                  );
                }
                if (points.isEmpty) continue;
                canvas.moveTo(points.first.x, points.first.y);
                for (final point in points.skip(1)) {
                  canvas.lineTo(point.x, point.y);
                }
                canvas.strokePath();
                for (final point in points) {
                  canvas.setColor(color);
                  canvas.drawEllipse(point.x, point.y, 2.8, 2.8);
                  canvas.fillPath();
                }
              }
            },
          ),
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(_trendLabel(buckets.first)),
            pw.Text(_trendLabel(buckets.last)),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfProductTrendRow(_ProductTrendSeries series, int index) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4),
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      color: PdfColors.yellow100,
      child: pw.Row(
        children: [
          pw.Container(
            width: 10,
            height: 10,
            color: _pdfTrendColors[index % _pdfTrendColors.length],
          ),
          pw.SizedBox(width: 7),
          pw.Expanded(child: pw.Text(series.name)),
          pw.Text('PHP ${_money(series.value)}'),
        ],
      ),
    );
  }

  Future<void> _print() async {
    final bytes = await _preparePdf(context, _buildPdf);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _download() async {
    final bytes = await _preparePdf(context, _buildPdf);
    await Printing.sharePdf(bytes: bytes, filename: 'sales-trends.pdf');
  }
}

class _TrendLineChart extends StatelessWidget {
  const _TrendLineChart({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: CustomPaint(
            painter: _LineChartPainter(
              values: values,
              max: max,
              xLabels: labels,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        Text(
          'Sales trend over time',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      ],
    );
  }
}

String _trendLabel(DateTime date) => date.day == 1 && date.month == 1
    ? '${date.year}'
    : '${date.year}-${date.month.toString().padLeft(2, '0')}';

const _pdfTrendColors = [
  PdfColors.indigo,
  PdfColors.teal,
  PdfColors.orange,
  PdfColors.red,
  PdfColors.green,
  PdfColors.purple,
  PdfColors.cyan,
  PdfColors.brown,
];

class _ProductTrendSeries {
  _ProductTrendSeries({required this.name});

  final String name;
  final points = <DateTime, double>{};

  double get value => points.values.fold(0, (total, amount) => total + amount);
}

class _SalesPrintDialog extends StatefulWidget {
  const _SalesPrintDialog({required this.sales});

  final List<DocumentSnapshot<Map<String, dynamic>>> sales;

  @override
  State<_SalesPrintDialog> createState() => _SalesPrintDialogState();
}

class _SalesPrintDialogState extends State<_SalesPrintDialog> {
  String _range = 'all';
  DateTimeRange? _customRange;
  DateTime? _comparisonMonth;
  DateTimeRange? _comparisonRange;
  String _paperSize = 'A4';
  String _orientation = 'portrait';
  String _margin = 'standard';
  final _sections = <String, bool>{
    'charts': true,
    'sales': true,
    'comparison': false,
  };

  List<DocumentSnapshot<Map<String, dynamic>>> get _filteredSales {
    if (_range == 'all') return widget.sales;
    final now = DateTime.now();
    final start = _range == 'month'
        ? DateTime(now.year, now.month, 1)
        : _customRange?.start;
    final end = _range == 'month'
        ? DateTime(now.year, now.month + 1, 1)
        : _customRange == null
        ? null
        : DateTime(
            _customRange!.end.year,
            _customRange!.end.month,
            _customRange!.end.day + 1,
          );
    if (start == null || end == null) return widget.sales;
    return widget.sales.where((sale) {
      final date = _date(sale.data()?['saleDate']);
      return date != null && !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }

  List<DocumentSnapshot<Map<String, dynamic>>> get _comparisonSales {
    if (!_sections['comparison']!) return const [];
    DateTime? start;
    DateTime? end;
    if (_range == 'month' && _comparisonMonth != null) {
      start = DateTime(_comparisonMonth!.year, _comparisonMonth!.month, 1);
      end = DateTime(_comparisonMonth!.year, _comparisonMonth!.month + 1, 1);
    } else if (_range == 'custom' && _comparisonRange != null) {
      start = _comparisonRange!.start;
      end = DateTime(
        _comparisonRange!.end.year,
        _comparisonRange!.end.month,
        _comparisonRange!.end.day + 1,
      );
    }
    if (start == null || end == null) return const [];
    return widget.sales.where((sale) {
      final date = _date(sale.data()?['saleDate']);
      return date != null && !date.isBefore(start!) && date.isBefore(end!);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSales;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(child: _buildEditor(context, filtered)),
        ),
      ),
    );
  }

  Widget _buildEditor(
    BuildContext context,
    List<DocumentSnapshot<Map<String, dynamic>>> filtered,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Print sales report',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${filtered.length} sales selected',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        _settingLabel('Sales range'),
        DropdownButtonFormField<String>(
          initialValue: _range,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All sales')),
            DropdownMenuItem(value: 'month', child: Text('This month')),
            DropdownMenuItem(value: 'custom', child: Text('Custom range')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            if (value == 'custom') {
              final range = await _pickDateRange(
                context,
                initialDateRange: _customRange,
              );
              if (range == null) return;
              setState(() {
                _customRange = range;
                _comparisonRange = null;
              });
            }
            setState(() {
              _range = value;
              if (value == 'all') {
                _sections['comparison'] = false;
                _comparisonMonth = null;
                _comparisonRange = null;
              }
            });
          },
        ),
        if (_range == 'custom' && _customRange != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${_shortDate(_customRange!.start)} - ${_shortDate(_customRange!.end)}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ),
        const SizedBox(height: 18),
        _settingLabel('Include in report'),
        _checkOption('charts', 'Charts and diagrams', Icons.bar_chart),
        _checkOption('sales', 'List of sales', Icons.receipt_long_outlined),
        if (_range != 'all')
          _checkOption('comparison', 'Comparison data', Icons.compare_arrows),
        if (_sections['comparison']!) _buildComparisonPicker(context),
        const SizedBox(height: 14),
        _settingLabel('Paper format'),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _paperSize,
                decoration: const InputDecoration(
                  labelText: 'Size',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'A4', child: Text('A4')),
                  DropdownMenuItem(value: 'Letter', child: Text('Letter')),
                  DropdownMenuItem(value: 'Legal', child: Text('Legal')),
                ],
                onChanged: (value) => setState(() => _paperSize = value!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _orientation,
                decoration: const InputDecoration(
                  labelText: 'Orientation',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'portrait', child: Text('Portrait')),
                  DropdownMenuItem(
                    value: 'landscape',
                    child: Text('Landscape'),
                  ),
                ],
                onChanged: (value) => setState(() => _orientation = value!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _margin,
          decoration: const InputDecoration(
            labelText: 'Margins',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'narrow', child: Text('Narrow')),
            DropdownMenuItem(value: 'standard', child: Text('Standard')),
            DropdownMenuItem(value: 'wide', child: Text('Wide')),
          ],
          onChanged: (value) => setState(() => _margin = value!),
        ),
        SizedBox(height: MediaQuery.sizeOf(context).width < 800 ? 18 : 36),
        const Divider(height: 28),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: filtered.isEmpty ? null : () => _download(filtered),
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Download'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: filtered.isEmpty ? null : () => _print(filtered),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _settingLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
  );

  Widget _checkOption(String key, String label, IconData icon) =>
      CheckboxListTile(
        value: _sections[key],
        onChanged: (value) => setState(() => _sections[key] = value ?? false),
        dense: true,
        contentPadding: EdgeInsets.zero,
        secondary: Icon(icon, size: 19),
        title: Text(label),
      );

  Widget _buildComparisonPicker(BuildContext context) {
    final label = _range == 'month'
        ? _comparisonMonth == null
              ? 'Choose comparison month'
              : 'Compare with ${_monthLabel(_comparisonMonth!)}'
        : _comparisonRange == null
        ? 'Choose comparison range'
        : 'Compare with ${_shortDate(_comparisonRange!.start)} - ${_shortDate(_comparisonRange!.end)}';
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: OutlinedButton.icon(
        onPressed: () async {
          if (_range == 'month') {
            final month = await _pickComparisonMonth(
              context,
              initialDate: _comparisonMonth,
            );
            if (month != null) setState(() => _comparisonMonth = month);
          } else {
            final range = await _pickDateRange(
              context,
              initialDateRange: _comparisonRange,
            );
            if (range != null) setState(() => _comparisonRange = range);
          }
        },
        icon: const Icon(Icons.calendar_month_outlined, size: 18),
        label: Text(label),
      ),
    );
  }

  Future<DateTimeRange?> _pickDateRange(
    BuildContext context, {
    DateTimeRange? initialDateRange,
  }) {
    return showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initialDateRange,
      helpText: 'Select sales range',
      cancelText: 'Cancel',
      confirmText: 'Apply range',
      builder: (context, child) =>
          Theme(data: _calendarTheme(context), child: child!),
    );
  }

  Future<DateTime?> _pickComparisonMonth(
    BuildContext context, {
    DateTime? initialDate,
  }) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initialDate ?? DateTime(now.year, now.month - 1, 1),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) =>
          Theme(data: _calendarTheme(context), child: child!),
    ).then((date) => date == null ? null : DateTime(date.year, date.month, 1));
  }

  ThemeData _calendarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: Colors.indigo,
        onPrimary: Colors.white,
        secondary: Colors.indigo,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        headerBackgroundColor: Colors.indigo,
        headerForegroundColor: Colors.white,
        headerHeadlineStyle: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        headerHelpStyle: TextStyle(
          color: Colors.indigo.shade100,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        dayShape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.grey.shade800;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.indigo;
          return Colors.transparent;
        }),
        rangeSelectionBackgroundColor: Colors.indigo.shade100,
        rangeSelectionOverlayColor: WidgetStatePropertyAll(
          Colors.indigo.withValues(alpha: 0.12),
        ),
        todayForegroundColor: const WidgetStatePropertyAll(Colors.indigo),
        todayBorder: const BorderSide(color: Colors.indigo),
        yearShape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        yearStyle: const TextStyle(fontWeight: FontWeight.w600),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.indigo;
          return Colors.transparent;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.amber.shade300;
          }
          return Colors.grey.shade700;
        }),
      ),
    );
  }

  String _monthLabel(DateTime date) => '${_monthName(date.month)} ${date.year}';

  String _monthName(int month) => const [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ][month];

  String _comparisonLabel() => _range == 'month'
      ? _monthLabel(_comparisonMonth!)
      : '${_shortDate(_comparisonRange!.start)} - ${_shortDate(_comparisonRange!.end)}';

  String _rangeLabel() {
    if (_range == 'all') return 'All sales';
    if (_range == 'month') return 'This month';
    return _customRange == null
        ? 'Custom range'
        : '${_shortDate(_customRange!.start)} - ${_shortDate(_customRange!.end)}';
  }

  PdfPageFormat get _pageFormat {
    final base = switch (_paperSize) {
      'Letter' => PdfPageFormat.letter,
      'Legal' => PdfPageFormat.legal,
      _ => PdfPageFormat.a4,
    };
    final oriented = _orientation == 'landscape' ? base.landscape : base;
    final margin = switch (_margin) {
      'narrow' => 24.0,
      'wide' => 64.0,
      _ => 40.0,
    };
    return oriented.copyWith(
      marginTop: margin,
      marginBottom: margin,
      marginLeft: margin,
      marginRight: margin,
    );
  }

  Future<void> _print(
    List<DocumentSnapshot<Map<String, dynamic>>> sales,
  ) async {
    final bytes = await _preparePdf(context, () => _buildPdf(sales));
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _download(
    List<DocumentSnapshot<Map<String, dynamic>>> sales,
  ) async {
    final bytes = await _preparePdf(context, () => _buildPdf(sales));
    await Printing.sharePdf(bytes: bytes, filename: 'sales-report.pdf');
  }

  Future<Uint8List> _buildPdf(
    List<DocumentSnapshot<Map<String, dynamic>>> sales,
  ) async {
    final document = pw.Document();
    final comparison = _comparisonSales;
    final comparisonTotal = comparison.fold<double>(
      0,
      (amount, sale) => amount + _number(sale.data()?['totalAmount']),
    );
    final total = sales.fold<double>(
      0,
      (amount, sale) => amount + _number(sale.data()?['totalAmount']),
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: _pageFormat,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Sales report',
              style: pw.TextStyle(fontSize: 23, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(
            '${_rangeLabel()} | Generated ${_shortDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 20),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Total sales: PHP ${_money(total)}',
            style: const pw.TextStyle(fontSize: 16),
          ),
          pw.Text(
            'Transactions: ${sales.length}',
            style: const pw.TextStyle(fontSize: 16),
          ),
          if (_sections['comparison']!) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Comparison data',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            if (comparison.isEmpty)
              pw.Text(
                'No comparison period selected',
                style: const pw.TextStyle(fontSize: 16),
              )
            else ...[
              pw.Text(
                '${_comparisonLabel()} total: PHP ${_money(comparisonTotal)}',
                style: const pw.TextStyle(fontSize: 16),
              ),
              pw.Text(
                'Comparison sales: ${comparison.length}',
                style: const pw.TextStyle(fontSize: 16),
              ),
            ],
          ],
          if (_sections['charts']!) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Daily sales chart',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            _pdfSalesChart(sales),
          ],
          if (_sections['sales']!) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'List of sales',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.TableHelper.fromTextArray(
              headers: const ['Customer', 'Receipt', 'Date', 'Total'],
              cellStyle: const pw.TextStyle(fontSize: 16),
              headerStyle: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
              data: [
                for (final sale in sales)
                  [
                    sale.data()?['customerName']?.toString() ??
                        'Walk-in customer',
                    sale.data()?['salesId']?.toString() ?? '-',
                    _dateLabel(sale.data()?['saleDate']),
                    'PHP ${_money(_number(sale.data()?['totalAmount']))}',
                  ],
              ],
            ),
          ],
        ],
      ),
    );
    return Uint8List.fromList(await document.save());
  }

  pw.Widget _pdfSalesChart(List<DocumentSnapshot<Map<String, dynamic>>> sales) {
    final buckets = <DateTime, double>{};
    for (final sale in sales) {
      final date = _date(sale.data()?['saleDate']);
      if (date == null) continue;
      final bucket = _range == 'month' || _range == 'custom'
          ? DateTime(date.year, date.month, date.day)
          : DateTime(date.year, date.month);
      buckets[bucket] =
          (buckets[bucket] ?? 0) + _number(sale.data()?['totalAmount']);
    }
    final values = buckets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final maximum = values.fold<double>(
      0,
      (current, entry) => entry.value > current ? entry.value : current,
    );
    if (values.isEmpty || maximum == 0) {
      return pw.Text('No chart data available');
    }
    return pw.Column(
      children: [
        for (final entry in values)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 55,
                  child: pw.Text('PHP ${_money(entry.value)}'),
                ),
                pw.SizedBox(width: 6),
                pw.Container(
                  height: 8,
                  width: 220 * entry.value / maximum,
                  color: PdfColors.indigo,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InventoryReport extends StatefulWidget {
  const _InventoryReport({
    required this.data,
    required this.searchTerm,
    required this.onSearch,
  });

  final _ReportData data;
  final String searchTerm;
  final ValueChanged<String> onSearch;

  @override
  State<_InventoryReport> createState() => _InventoryReportState();
}

class _InventoryReportState extends State<_InventoryReport> {
  String _comparisonPeriod = 'month';
  String? _selectedProductId;
  bool _showProductTrends = false;

  @override
  Widget build(BuildContext context) {
    if (_showProductTrends) {
      return _ProductSoldTrendsPage(
        data: widget.data,
        onBack: () => setState(() => _showProductTrends = false),
      );
    }
    final rows = widget.data.products
        .where(
          (product) => (product.data()?['productName'] ?? '')
              .toString()
              .toLowerCase()
              .contains(widget.searchTerm.toLowerCase()),
        )
        .toList();
    final stockByProduct = {
      for (final item in widget.data.inventory)
        _referenceId(item.data()?['productId'] ?? item.data()?['product_dID']):
            item.data() ?? {},
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      children: [
        const _ReportIntro(
          title: 'Inventory & movement report',
          subtitle:
              'Compare current stock, reorder levels, and outgoing sales rate.',
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: widget.onSearch,
          decoration: const InputDecoration(
            labelText: 'Search products',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Sales comparison',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: _comparisonPeriod,
                decoration: const InputDecoration(
                  labelText: 'Period',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'month', child: Text('Monthly')),
                  DropdownMenuItem(value: 'year', child: Text('Yearly')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _comparisonPeriod = value);
                  }
                },
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => setState(() => _showProductTrends = true),
              icon: const Icon(Icons.show_chart_outlined),
              label: const Text('Product sales trends'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ReportPanel(
          child: _ProductStockComparisonChart(
            data: widget.data,
            stockByProduct: stockByProduct,
            comparisonPeriod: _comparisonPeriod,
            selectedProductId: _selectedProductId,
          ),
        ),
        const SizedBox(height: 20),
        _ReportTableHeader(
          labels: const ['Product', 'Stock', 'Reorder point', 'Status'],
        ),
        for (final product in rows)
          _InventoryReportRow(
            product: product,
            inventory: stockByProduct[product.id] ?? {},
            selected: product.id == _selectedProductId,
            onTap: () => setState(() => _selectedProductId = product.id),
          ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No inventory records')),
          ),
      ],
    );
  }
}

class _ProductSoldTrendsPage extends StatelessWidget {
  const _ProductSoldTrendsPage({required this.data, required this.onBack});

  final _ReportData data;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
    children: [
      Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back to inventory and movement',
            icon: const Icon(Icons.arrow_back),
          ),
          const Expanded(
            child: _ReportIntro(
              title: 'Product sales trends',
              subtitle: 'Compare units sold by product over time.',
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      const Text(
        'Top 5 trend products sold',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        'Showing the five products with the highest sold quantity.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      const SizedBox(height: 10),
      _SummaryInventoryInsights(data: data),
    ],
  );
}

class _MovementReport extends StatefulWidget {
  const _MovementReport({
    required this.data,
    required this.searchTerm,
    required this.onSearch,
  });

  final _ReportData data;
  final String searchTerm;
  final ValueChanged<String> onSearch;

  @override
  State<_MovementReport> createState() => _MovementReportState();
}

class _MovementReportState extends State<_MovementReport> {
  String _damagePeriod = 'month';

  @override
  Widget build(BuildContext context) {
    final rows = widget.data.movements
        .where(
          (movement) =>
              movement.data()?['movementType']?.toString() == 'damaged' &&
              '${movement.data()?['productId'] ?? ''} ${movement.data()?['reason'] ?? ''}'
                  .toLowerCase()
                  .contains(widget.searchTerm.toLowerCase()),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      children: [
        const _ReportIntro(
          title: 'Product damage report',
          subtitle: 'Damaged stock incidents recorded from the Products page.',
        ),
        const SizedBox(height: 14),
        TextField(
          onChanged: widget.onSearch,
          decoration: const InputDecoration(
            labelText: 'Search damage reason or product',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Damage trend',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: _damagePeriod,
                decoration: const InputDecoration(
                  labelText: 'Period',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'month', child: Text('Monthly')),
                  DropdownMenuItem(value: 'year', child: Text('Yearly')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _damagePeriod = value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ReportPanel(
          child: _DamageTrendChart(
            movements: widget.data.movements,
            period: _damagePeriod,
          ),
        ),
        const SizedBox(height: 20),
        _ReportTableHeader(
          labels: const ['Damage', 'Quantity', 'Reason', 'Date'],
        ),
        for (final movement in rows) _MovementReportRow(movement: movement),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No damage reports')),
          ),
      ],
    );
  }
}

class _DamageTrendChart extends StatelessWidget {
  const _DamageTrendChart({required this.movements, required this.period});

  final List<DocumentSnapshot<Map<String, dynamic>>> movements;
  final String period;

  @override
  Widget build(BuildContext context) {
    final totals = <DateTime, double>{};
    for (final movement in movements) {
      final data = movement.data() ?? {};
      if (data['movementType']?.toString() != 'damaged') continue;
      final date = _date(data['movementDate']);
      if (date == null) continue;
      final bucket = period == 'year'
          ? DateTime(date.year)
          : DateTime(date.year, date.month);
      totals[bucket] = (totals[bucket] ?? 0) + _number(data['quantity']);
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final values = [for (final entry in entries) entry.value];
    if (values.isEmpty) {
      return const SizedBox(
        height: 190,
        child: Center(child: Text('No damage trend data')),
      );
    }
    final total = values.fold<double>(0, (amount, value) => amount + value);
    final maximum = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: CustomPaint(
            painter: _LineChartPainter(
              values: values,
              max: maximum,
              xLabels: [for (final entry in entries) _trendLabel(entry.key)],
              valuePrefix: '',
            ),
            child: const SizedBox.expand(),
          ),
        ),
        Text(
          period == 'year'
              ? 'Yearly damaged quantity'
              : 'Monthly damaged quantity',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
        Text(
          'Total damaged: ${_money(total)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ReportIntro extends StatelessWidget {
  const _ReportIntro({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 5),
      Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
    ],
  );
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 15),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.indigo.withValues(alpha: 0.12)),
    ),
    child: child,
  );
}

class _DailySalesTrendChart extends StatelessWidget {
  const _DailySalesTrendChart({required this.sales});
  final List<DocumentSnapshot<Map<String, dynamic>>> sales;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final values = List<double>.filled(30, 0);
    for (final sale in sales) {
      final date = _date(sale.data()?['saleDate']);
      if (date == null) continue;
      final age = DateTime(
        today.year,
        today.month,
        today.day,
      ).difference(DateTime(date.year, date.month, date.day)).inDays;
      if (age >= 0 && age < 30) {
        values[29 - age] += _number(sale.data()?['totalAmount']);
      }
    }
    final max = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    final labels = [
      for (var index = 0; index < values.length; index++)
        _shortDate(today.subtract(Duration(days: values.length - 1 - index))),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: CustomPaint(
            painter: _LineChartPainter(
              values: values,
              max: max,
              xLabels: labels,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          max == 0
              ? 'No sales recorded in the last 30 days'
              : 'Daily total sales in PHP',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
      ],
    );
  }
}

class _SummaryInventoryInsights extends StatefulWidget {
  const _SummaryInventoryInsights({required this.data});

  final _ReportData data;

  @override
  State<_SummaryInventoryInsights> createState() =>
      _SummaryInventoryInsightsState();
}

class _SummaryInventoryInsightsState extends State<_SummaryInventoryInsights> {
  String _period = 'month';

  @override
  Widget build(BuildContext context) {
    final names = {
      for (final product in widget.data.products)
        product.id: product.data()?['productName']?.toString() ?? 'Product',
    };
    final now = DateTime.now();
    final buckets = <DateTime, Map<String, double>>{};
    final coverage = <String, (double, double)>{};
    for (final movement in widget.data.movements) {
      final data = movement.data() ?? {};
      final productId = _referenceId(data['productId'] ?? data['product_dID']);
      if (!names.containsKey(productId)) continue;
      final date = _date(data['movementDate']);
      if (date == null) continue;
      final inPeriod = _period == 'year'
          ? date.year == now.year
          : date.year == now.year && date.month == now.month;
      if (!inPeriod) continue;
      final quantity = _number(data['quantity']);
      final current = coverage[productId] ?? (0, 0);
      if (data['movementType']?.toString() == 'restock') {
        coverage[productId] = (current.$1 + quantity, current.$2);
      } else if (data['movementType']?.toString() == 'sale') {
        coverage[productId] = (current.$1, current.$2 + quantity);
        final bucket = _period == 'year'
            ? DateTime(date.year, date.month)
            : DateTime(date.year, date.month, date.day);
        final totals = buckets.putIfAbsent(bucket, () => {});
        totals[productId] = (totals[productId] ?? 0) + quantity;
      }
    }
    final entries = buckets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final ranked = coverage.entries.toList()
      ..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final topIds = ranked.take(5).map((entry) => entry.key).toList();
    return _ReportPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Trend period',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  initialValue: _period,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'month', child: Text('Monthly')),
                    DropdownMenuItem(value: 'year', child: Text('Yearly')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _period = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Top 5 trend products sold',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const Text('No product sales movement data for this period.')
          else
            SizedBox(
              height: 270,
              child: CustomPaint(
                painter: _SummaryProductTrendsPainter(
                  buckets: entries,
                  productIds: topIds,
                  productNames: names,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Restock coverage: incoming restock units compared with outgoing sold units. 100% or higher means replenishment kept up.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (final entry in ranked)
            _SummaryCoverageRow(
              name: names[entry.key] ?? 'Product',
              restocked: entry.value.$1,
              sold: entry.value.$2,
            ),
        ],
      ),
    );
  }
}

class _SummaryCoverageRow extends StatelessWidget {
  const _SummaryCoverageRow({
    required this.name,
    required this.restocked,
    required this.sold,
  });

  final String name;
  final double restocked;
  final double sold;

  @override
  Widget build(BuildContext context) {
    final rate = sold == 0 ? null : restocked / sold * 100;
    final color = sold == 0
        ? Colors.grey
        : rate! >= 100
        ? Colors.green
        : Colors.red;
    final status = sold == 0
        ? 'No sales'
        : rate! >= 100
        ? 'Keeping up'
        : 'Below sales';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(name),
      subtitle: Text('Restocked ${_money(restocked)}  |  Sold ${_money(sold)}'),
      trailing: Text(
        rate == null ? status : '${rate.toStringAsFixed(0)}%  $status',
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SummaryProductTrendsPainter extends CustomPainter {
  const _SummaryProductTrendsPainter({
    required this.buckets,
    required this.productIds,
    required this.productNames,
  });

  final List<MapEntry<DateTime, Map<String, double>>> buckets;
  final List<String> productIds;
  final Map<String, String> productNames;

  @override
  void paint(Canvas canvas, Size size) {
    const leftInset = 76.0;
    const topInset = 8.0;
    const bottomInset = 34.0;
    final width = size.width - leftInset;
    final height = size.height - topInset - bottomInset;
    final maximum = buckets
        .expand((entry) => productIds.map((id) => entry.value[id] ?? 0))
        .fold<double>(0, (current, value) => value > current ? value : current);
    final axis = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    for (var tick = 0; tick <= 4; tick++) {
      final fraction = tick / 4;
      final y = topInset + height * (1 - fraction);
      canvas.drawLine(Offset(leftInset, y), Offset(size.width, y), axis);
      _label(
        canvas,
        _compactNumber(maximum * fraction),
        Offset(0, y - 6),
        leftInset - 5,
        TextAlign.right,
      );
    }
    if (maximum == 0) return;
    const colors = [
      Colors.indigo,
      Colors.orange,
      Colors.teal,
      Colors.red,
      Colors.purple,
    ];
    for (var series = 0; series < productIds.length; series++) {
      final points = [
        for (var index = 0; index < buckets.length; index++)
          Offset(
            buckets.length == 1
                ? leftInset + width / 2
                : leftInset + width * index / (buckets.length - 1),
            topInset +
                height -
                (buckets[index].value[productIds[series]] ?? 0) /
                    maximum *
                    height,
          ),
      ];
      final color = colors[series % colors.length];
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
      for (final point in points) {
        canvas.drawCircle(point, 3, Paint()..color = color);
      }
      _label(
        canvas,
        productNames[productIds[series]] ?? 'Product',
        Offset(8 + series * 92, size.height - 14),
        88,
        TextAlign.left,
        color: color,
      );
    }
    for (final index in [0, if (buckets.length > 1) buckets.length - 1]) {
      final x = buckets.length == 1
          ? leftInset + width / 2
          : leftInset + width * index / (buckets.length - 1);
      _label(
        canvas,
        _trendLabel(buckets[index].key),
        Offset(x - 28, topInset + height + 5),
        56,
        TextAlign.center,
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset offset,
    double width,
    TextAlign align, {
    Color color = Colors.grey,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SummaryProductTrendsPainter oldDelegate) =>
      true;
}

class _InventoryMovementPieChart extends StatelessWidget {
  const _InventoryMovementPieChart({
    required this.inventory,
    required this.movements,
  });

  final List<DocumentSnapshot<Map<String, dynamic>>> inventory;
  final List<DocumentSnapshot<Map<String, dynamic>>> movements;

  @override
  Widget build(BuildContext context) {
    final stock = inventory.fold<double>(
      0,
      (total, item) =>
          total +
          _number(
            item.data()?['quantityOnHand'] ?? item.data()?['current_stock'],
          ),
    );
    final sold = _movementTotal('sale');
    final damaged = _movementTotal('damaged');
    final values = [stock, sold, damaged];
    final total = values.fold<double>(0, (amount, value) => amount + value);
    if (total == 0) {
      return const SizedBox(
        height: 210,
        child: Center(child: Text('No inventory movement data yet')),
      );
    }
    const labels = ['Stock left', 'Sold', 'Damaged'];
    const colors = [Colors.indigo, Colors.orange, Colors.red];
    return Row(
      children: [
        SizedBox(
          width: 210,
          height: 210,
          child: CustomPaint(
            painter: _MovementPiePainter(values: values, colors: colors),
            child: Center(
              child: Text(
                '${_compactNumber(total)}\ntotal units',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < labels.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[index],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(labels[index])),
                      Text(
                        '${_money(values[index])} (${(values[index] / total * 100).toStringAsFixed(1)}%)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  double _movementTotal(String type) => movements
      .where((movement) => movement.data()?['movementType']?.toString() == type)
      .fold<double>(
        0,
        (total, movement) => total + _number(movement.data()?['quantity']),
      );
}

class _MovementPiePainter extends CustomPainter {
  const _MovementPiePainter({required this.values, required this.colors});

  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (amount, value) => amount + value);
    if (total == 0) return;
    final bounds = Offset.zero & size;
    final rect = Rect.fromCircle(
      center: bounds.center,
      radius: size.shortestSide / 2 - 8,
    );
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * math.pi * 2;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = colors[index]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _MovementPiePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({
    required this.values,
    required this.max,
    this.xLabels = const [],
    this.valuePrefix = 'PHP ',
  });
  final List<double> values;
  final double max;
  final List<String> xLabels;
  final String valuePrefix;

  @override
  void paint(Canvas canvas, Size size) {
    final leftInset = _chartLabelInset('$valuePrefix${_compactNumber(max)}');
    const bottomInset = 24.0;
    const topInset = 8.0;
    final chartWidth = size.width - leftInset;
    final chartHeight = size.height - bottomInset - topInset;
    final axis = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(leftInset, topInset + chartHeight),
      Offset(size.width, topInset + chartHeight),
      axis,
    );
    final labelStyle = const TextStyle(color: Colors.grey, fontSize: 10);
    for (var tick = 0; tick <= 4; tick++) {
      final fraction = tick / 4;
      final y = topInset + chartHeight * (1 - fraction);
      canvas.drawLine(Offset(leftInset, y), Offset(size.width, y), axis);
      _drawText(
        canvas,
        '$valuePrefix${_compactNumber(max * fraction)}',
        Offset(0, y - 6),
        labelStyle,
        width: leftInset - 5,
        align: TextAlign.right,
      );
    }
    if (max == 0) return;
    final line = Paint()
      ..color = Colors.indigo
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      points.add(
        Offset(
          values.length == 1
              ? leftInset + chartWidth / 2
              : leftInset + chartWidth * index / (values.length - 1),
          topInset + chartHeight - (values[index] / max * chartHeight),
        ),
      );
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = Colors.indigo;
    for (final point in points.where(
      (point) => point.dy < size.height - bottomInset,
    )) {
      canvas.drawCircle(point, 3, dot);
    }
    if (xLabels.isNotEmpty) {
      final labelIndexes = _labelIndexes(xLabels.length);
      for (final index in labelIndexes) {
        final x = values.length == 1
            ? leftInset + chartWidth / 2
            : leftInset + chartWidth * index / (values.length - 1);
        _drawText(
          canvas,
          xLabels[index],
          Offset(x - 28, topInset + chartHeight + 5),
          labelStyle,
          width: 56,
          align: TextAlign.center,
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    required double width,
    required TextAlign align,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  List<int> _labelIndexes(int count) {
    if (count <= 4) return [for (var index = 0; index < count; index++) index];
    return [0, count ~/ 3, (count * 2) ~/ 3, count - 1];
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values ||
      oldDelegate.max != max ||
      oldDelegate.xLabels != xLabels ||
      oldDelegate.valuePrefix != valuePrefix;
}

String _compactNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

double _chartLabelInset(String label) {
  final painter = TextPainter(
    text: TextSpan(text: label, style: const TextStyle(fontSize: 10)),
    textDirection: TextDirection.ltr,
  )..layout();
  return (painter.width + 14).clamp(76.0, 160.0).toDouble();
}

String _shortDate(DateTime date) => '${date.month}/${date.day}';

class _IncomeChart extends StatelessWidget {
  const _IncomeChart({required this.sales, required this.period});
  final List<DocumentSnapshot<Map<String, dynamic>>> sales;
  final String period;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final buckets = <DateTime, double>{};
    for (final sale in sales) {
      final date = _date(sale.data()?['saleDate']);
      if (date == null) continue;
      final bucket = period == 'month'
          ? DateTime(date.year, date.month, date.day)
          : DateTime(date.year, date.month);
      buckets[bucket] =
          (buckets[bucket] ?? 0) + _number(sale.data()?['totalAmount']);
    }
    final values = buckets.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final chartValues = [for (final entry in values) entry.value];
    final max = values.fold<double>(
      0,
      (current, entry) => entry.value > current ? entry.value : current,
    );
    if (chartValues.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text('No sales chart data')),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: CustomPaint(
            painter: _LineChartPainter(
              values: chartValues,
              max: max,
              xLabels: [
                for (final entry in values)
                  period == 'month'
                      ? _shortDate(entry.key)
                      : '${entry.key.year}',
              ],
            ),
            child: const SizedBox.expand(),
          ),
        ),
        Text(
          period == 'month' ? 'Daily sales this month' : 'Monthly sales trend',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
        ),
        Text(
          'PHP ${_money(chartValues.fold<double>(0, (total, value) => total + value))} total',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text(
          'Updated ${_shortDate(today)}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
      ],
    );
  }
}

class _ProductStockComparisonChart extends StatelessWidget {
  const _ProductStockComparisonChart({
    required this.data,
    required this.stockByProduct,
    required this.comparisonPeriod,
    required this.selectedProductId,
  });
  final _ReportData data;
  final Map<String, Map<String, dynamic>> stockByProduct;
  final String comparisonPeriod;
  final String? selectedProductId;

  @override
  Widget build(BuildContext context) {
    final matchingProducts = selectedProductId == null
        ? const <DocumentSnapshot<Map<String, dynamic>>>[]
        : data.products.where((item) => item.id == selectedProductId).toList();
    final product = matchingProducts.isEmpty ? null : matchingProducts.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 12,
          children: [
            Text('Inventory movement', style: TextStyle(color: Colors.indigo)),
            Text('Units sold', style: TextStyle(color: Colors.orange)),
          ],
        ),
        const SizedBox(height: 10),
        if (product == null)
          const Text('Select an inventory row below to view its movements.')
        else ...[
          Text(
            '${product.data()?['productName'] ?? 'Product'} movements for the selected ${comparisonPeriod == 'year' ? 'year' : 'month'}.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 270,
            child: CustomPaint(
              painter: _ProductMovementPainter(
                movements: _movementsForProduct(product.id),
                period: comparisonPeriod,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ],
    );
  }

  List<DocumentSnapshot<Map<String, dynamic>>> _movementsForProduct(
    String productId,
  ) {
    final now = DateTime.now();
    return data.movements.where((movement) {
      final movementData = movement.data() ?? {};
      final date = _date(movementData['movementDate']);
      final inPeriod =
          date != null &&
          (comparisonPeriod == 'year'
              ? date.year == now.year
              : date.year == now.year && date.month == now.month);
      return inPeriod &&
          _referenceId(
                movementData['productId'] ?? movementData['product_dID'],
              ) ==
              productId;
    }).toList()..sort((a, b) {
      final aDate = _date(a.data()?['movementDate']);
      final bDate = _date(b.data()?['movementDate']);
      return (aDate ?? DateTime(2000)).compareTo(bDate ?? DateTime(2000));
    });
  }
}

class _ProductMovementPainter extends CustomPainter {
  const _ProductMovementPainter({
    required this.movements,
    required this.period,
  });

  final List<DocumentSnapshot<Map<String, dynamic>>> movements;
  final String period;

  @override
  void paint(Canvas canvas, Size size) {
    final grouped = <DateTime, (double stock, double sold)>{};
    for (final movement in movements) {
      final data = movement.data() ?? {};
      final date = _date(data['movementDate']);
      if (date == null) continue;
      final bucket = period == 'year'
          ? DateTime(date.year, date.month)
          : DateTime(date.year, date.month, date.day);
      final previous = grouped[bucket] ?? (0, 0);
      grouped[bucket] = (
        _number(data['newQuantity']),
        previous.$2 +
            (data['movementType']?.toString() == 'sale'
                ? _number(data['quantity'])
                : 0),
      );
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    _InventoryStockSalesPainter(
      stock: [for (final entry in entries) entry.value.$1],
      sold: [for (final entry in entries) entry.value.$2],
      labels: [
        for (final entry in entries)
          period == 'year'
              ? '${entry.key.month}/${entry.key.year}'
              : _shortDate(entry.key),
      ],
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _ProductMovementPainter oldDelegate) =>
      oldDelegate.movements != movements || oldDelegate.period != period;
}

class _InventoryStockSalesPainter extends CustomPainter {
  const _InventoryStockSalesPainter({
    required this.stock,
    required this.sold,
    required this.labels,
  });

  final List<double> stock;
  final List<double> sold;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    const bottomInset = 34.0;
    const topInset = 8.0;
    final maximum = [
      ...stock,
      ...sold,
    ].fold<double>(0, (current, value) => value > current ? value : current);
    final leftInset = _chartLabelInset(_compactNumber(maximum));
    final chartWidth = size.width - leftInset;
    final chartHeight = size.height - topInset - bottomInset;
    final axis = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    for (var tick = 0; tick <= 4; tick++) {
      final fraction = tick / 4;
      final y = topInset + chartHeight * (1 - fraction);
      canvas.drawLine(Offset(leftInset, y), Offset(size.width, y), axis);
      _drawText(
        canvas,
        _compactNumber(maximum * fraction),
        Offset(0, y - 6),
        leftInset - 5,
        TextAlign.right,
      );
    }
    if (maximum == 0) return;
    _drawSeries(
      canvas,
      stock,
      maximum,
      Colors.indigo,
      leftInset,
      chartWidth,
      chartHeight,
      topInset,
    );
    _drawSeries(
      canvas,
      sold,
      maximum,
      Colors.orange,
      leftInset,
      chartWidth,
      chartHeight,
      topInset,
    );
    for (var index = 0; index < labels.length; index++) {
      final x = labels.length == 1
          ? leftInset + chartWidth / 2
          : leftInset + chartWidth * index / (labels.length - 1);
      _drawText(
        canvas,
        labels[index],
        Offset(x - 35, topInset + chartHeight + 6),
        70,
        TextAlign.center,
      );
    }
  }

  void _drawSeries(
    Canvas canvas,
    List<double> values,
    double maximum,
    Color color,
    double leftInset,
    double chartWidth,
    double chartHeight,
    double topInset,
  ) {
    if (values.isEmpty) return;
    final points = [
      for (var index = 0; index < values.length; index++)
        Offset(
          values.length == 1
              ? leftInset + chartWidth / 2
              : leftInset + chartWidth * index / (values.length - 1),
          topInset + chartHeight - values[index] / maximum * chartHeight,
        ),
    ];
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
    for (final point in points) {
      canvas.drawCircle(point, 3, Paint()..color = color);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    double width,
    TextAlign align,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
    )..layout(maxWidth: width);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _InventoryStockSalesPainter oldDelegate) =>
      oldDelegate.stock != stock ||
      oldDelegate.sold != sold ||
      oldDelegate.labels != labels;
}

class _ReportModule extends StatelessWidget {
  const _ReportModule({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.indigo),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(description),
      trailing: const Icon(Icons.arrow_forward_ios, size: 15),
    ),
  );
}

class _ReportTableHeader extends StatelessWidget {
  const _ReportTableHeader({required this.labels});
  final List<String> labels;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: Colors.indigo.withValues(alpha: 0.07),
    child: Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
      ],
    ),
  );
}

class _SalesReportRow extends StatelessWidget {
  const _SalesReportRow({required this.sale});
  final DocumentSnapshot<Map<String, dynamic>> sale;

  @override
  Widget build(BuildContext context) {
    final data = sale.data() ?? {};
    return ListTile(
      title: Text(data['customerName']?.toString() ?? 'Walk-in customer'),
      subtitle: Text(
        '${data['salesId'] ?? 'Receipt not recorded'}  •  ${_dateLabel(data['saleDate'])}',
      ),
      trailing: Text('PHP ${_money(_number(data['totalAmount']))}'),
    );
  }
}

class _InventoryReportRow extends StatelessWidget {
  const _InventoryReportRow({
    required this.product,
    required this.inventory,
    required this.selected,
    required this.onTap,
  });
  final DocumentSnapshot<Map<String, dynamic>> product;
  final Map<String, dynamic> inventory;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final stock = _number(
      inventory['quantityOnHand'] ?? inventory['current_stock'],
    );
    final reorder = _number(product.data()?['reorderPoint']);
    final status = stock <= 0
        ? 'Out of stock'
        : stock <= reorder
        ? 'Low stock'
        : 'In stock';
    return ListTile(
      selected: selected,
      selectedTileColor: Colors.indigo.withValues(alpha: 0.08),
      onTap: onTap,
      title: Text(product.data()?['productName']?.toString() ?? 'Product'),
      subtitle: Text('Stock: ${_money(stock)}  •  Reorder: ${_money(reorder)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

class _MovementReportRow extends StatelessWidget {
  const _MovementReportRow({required this.movement});
  final DocumentSnapshot<Map<String, dynamic>> movement;

  @override
  Widget build(BuildContext context) {
    final data = movement.data() ?? {};
    return ListTile(
      title: const Text('Damaged stock'),
      subtitle: Text(
        '${data['reason'] ?? '-'}  •  ${_dateLabel(data['movementDate'])}',
      ),
      trailing: Text('${data['quantity'] ?? 0} ${data['unit'] ?? ''}'),
    );
  }
}

String _referenceId(dynamic value) =>
    value is DocumentReference ? value.id : value?.toString() ?? '';
double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
String _money(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
DateTime? _date(dynamic value) => value is Timestamp
    ? value.toDate()
    : DateTime.tryParse(value?.toString() ?? '');
String _dateLabel(dynamic value) {
  final date = _date(value);
  return date == null
      ? 'Date not recorded'
      : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

bool _matchesPeriod(dynamic value, String period) {
  final date = _date(value);
  if (date == null || period == 'all') return true;
  final now = DateTime.now();
  if (period == 'day') {
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }
  return period == 'month'
      ? date.year == now.year && date.month == now.month
      : date.year == now.year;
}

Widget _error(String message) =>
    Center(child: Text(message, textAlign: TextAlign.center));
