import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _firebaseService = FirebaseService();
  int _section = 0;
  String _searchTerm = '';
  String _period = 'all';

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
  double get balances => sales.fold(
    0,
    (total, sale) => total + _number(sale.data()?['balanceDue']),
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
              label: 'Customer balances',
              value: 'PHP ${_money(data.balances)}',
              icon: Icons.account_balance_wallet_outlined,
              color: Colors.orange,
            ),
            _ReportMetric(
              label: 'Stock quantity',
              value: _money(data.stock),
              icon: Icons.inventory_2_outlined,
              color: Colors.teal,
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
          description: 'Income, payments, balances, and transaction trends.',
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

class _SalesReport extends StatelessWidget {
  const _SalesReport({
    required this.data,
    required this.period,
    required this.onPeriodChanged,
  });

  final _ReportData data;
  final String period;
  final ValueChanged<String> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final filtered = data.sales
        .where((sale) => _matchesPeriod(sale.data()?['saleDate'], period))
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
      children: [
        const _ReportIntro(
          title: 'Sales report',
          subtitle:
              'Income, collection, customer balances, and transaction history.',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Text('Period', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 12),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: period,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All time')),
                  DropdownMenuItem(value: 'month', child: Text('This month')),
                  DropdownMenuItem(value: 'year', child: Text('This year')),
                ],
                onChanged: (value) {
                  if (value != null) onPeriodChanged(value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ReportPanel(child: _IncomeChart(sales: filtered)),
        const SizedBox(height: 20),
        _ReportTableHeader(
          labels: const ['Customer', 'Receipt', 'Date', 'Total', 'Balance'],
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
}

class _InventoryReport extends StatelessWidget {
  const _InventoryReport({
    required this.data,
    required this.searchTerm,
    required this.onSearch,
  });

  final _ReportData data;
  final String searchTerm;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final rows = data.products
        .where(
          (product) => (product.data()?['productName'] ?? '')
              .toString()
              .toLowerCase()
              .contains(searchTerm.toLowerCase()),
        )
        .toList();
    final stockByProduct = {
      for (final item in data.inventory)
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
          onChanged: onSearch,
          decoration: const InputDecoration(
            labelText: 'Search products',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        _ReportPanel(
          child: _ProductStockComparisonChart(
            data: data,
            stockByProduct: stockByProduct,
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

class _MovementReport extends StatelessWidget {
  const _MovementReport({
    required this.data,
    required this.searchTerm,
    required this.onSearch,
  });

  final _ReportData data;
  final String searchTerm;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final rows = data.movements
        .where(
          (movement) =>
              movement.data()?['movementType']?.toString() == 'damaged' &&
              '${movement.data()?['productId'] ?? ''} ${movement.data()?['reason'] ?? ''}'
                  .toLowerCase()
                  .contains(searchTerm.toLowerCase()),
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
          onChanged: onSearch,
          decoration: const InputDecoration(
            labelText: 'Search damage reason or product',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
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
      if (age >= 0 && age < 30)
        values[29 - age] += _number(sale.data()?['totalAmount']);
    }
    final max = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: CustomPaint(
            painter: _LineChartPainter(values: values, max: max),
            child: const SizedBox.expand(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_shortDate(today.subtract(const Duration(days: 29)))),
            const Text('PHP'),
            Text(_shortDate(today)),
          ],
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

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({required this.values, required this.max});
  final List<double> values;
  final double max;

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      axis,
    );
    if (max == 0) return;
    final line = Paint()
      ..color = Colors.indigo
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final points = <Offset>[];
    for (var index = 0; index < values.length; index++) {
      points.add(
        Offset(
          size.width * index / (values.length - 1),
          size.height - (values[index] / max * (size.height - 12)),
        ),
      );
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = Colors.indigo;
    for (final point in points.where((point) => point.dy < size.height - 1)) {
      canvas.drawCircle(point, 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.max != max;
}

String _shortDate(DateTime date) => '${date.month}/${date.day}';

class _IncomeChart extends StatelessWidget {
  const _IncomeChart({required this.sales});
  final List<DocumentSnapshot<Map<String, dynamic>>> sales;

  @override
  Widget build(BuildContext context) {
    final values = sales
        .take(12)
        .map((sale) => _number(sale.data()?['totalAmount']))
        .toList()
        .reversed
        .toList();
    final max = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    if (values.isEmpty) {
      return const SizedBox(
        height: 150,
        child: Center(child: Text('No sales chart data')),
      );
    }
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final value in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FractionallySizedBox(
                  heightFactor: max == 0 ? 0 : value / max,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.indigo,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductStockComparisonChart extends StatelessWidget {
  const _ProductStockComparisonChart({
    required this.data,
    required this.stockByProduct,
  });
  final _ReportData data;
  final Map<String, Map<String, dynamic>> stockByProduct;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final product in data.products)
        (
          product.data()?['productName']?.toString() ?? 'Product',
          _number(
            stockByProduct[product.id]?['quantityOnHand'] ??
                stockByProduct[product.id]?['current_stock'],
          ),
          _number(product.data()?['reorderPoint']),
          _number(product.data()?['maximumStock']),
        ),
    ]..sort((a, b) => (a.$2 <= a.$3 ? 0 : 1).compareTo(b.$2 <= b.$3 ? 0 : 1));
    final scale = rows.fold<double>(0, (max, row) {
      final rowMax = [row.$2, row.$3, row.$4].reduce((a, b) => a > b ? a : b);
      return rowMax > max ? rowMax : max;
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 12,
          children: [
            Text('Current stock', style: TextStyle(color: Colors.indigo)),
            Text('Reorder marker', style: TextStyle(color: Colors.orange)),
            Text('Maximum marker', style: TextStyle(color: Colors.red)),
          ],
        ),
        const SizedBox(height: 10),
        for (final row in rows.take(12))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    row.$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(height: 12, color: Colors.grey.shade200),
                      FractionallySizedBox(
                        widthFactor: scale == 0 ? 0 : row.$2 / scale,
                        child: Container(
                          height: 12,
                          color: row.$2 <= row.$3
                              ? Colors.orange
                              : Colors.indigo,
                        ),
                      ),
                      if (row.$3 > 0)
                        Positioned(
                          left: scale == 0 ? 0 : row.$3 / scale * 100,
                          child: const SizedBox(
                            height: 18,
                            child: VerticalDivider(
                              color: Colors.orange,
                              width: 1,
                            ),
                          ),
                        ),
                      if (row.$4 > 0 && scale > 0)
                        Positioned(
                          left: row.$4 / scale * 100,
                          child: const SizedBox(
                            height: 18,
                            child: VerticalDivider(color: Colors.red, width: 1),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('${_money(row.$2)} boxes'),
              ],
            ),
          ),
      ],
    );
  }
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
  const _InventoryReportRow({required this.product, required this.inventory});
  final DocumentSnapshot<Map<String, dynamic>> product;
  final Map<String, dynamic> inventory;

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
      title: Text(product.data()?['productName']?.toString() ?? 'Product'),
      subtitle: Text('Stock: ${_money(stock)}  •  Reorder: ${_money(reorder)}'),
      trailing: Text(status),
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
  return period == 'month'
      ? date.year == now.year && date.month == now.month
      : date.year == now.year;
}

Widget _error(String message) =>
    Center(child: Text(message, textAlign: TextAlign.center));
