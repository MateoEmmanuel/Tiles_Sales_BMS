import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _firebaseService = FirebaseService();
  @override
  Widget build(BuildContext context) {
    if (!_firebaseService.isInitialized) {
      return const Center(child: Text('Firebase is not initialized'));
    }
    return const _TransactionHistoryView();
  }
}

class _TransactionHistoryView extends StatefulWidget {
  const _TransactionHistoryView();

  @override
  State<_TransactionHistoryView> createState() =>
      _TransactionHistoryViewState();
}

class _TransactionHistoryViewState extends State<_TransactionHistoryView> {
  final _searchController = TextEditingController();
  String _searchTerm = '';
  String _sort = 'latest';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sales = FirebaseService().getFirestore().collection('sales');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: sales.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _error('Could not load sales.\n${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!.docs.toList()
          ..sort((a, b) => _compareSales(a, b, _sort));
        final filtered = records.where(_matches).toList();
        return Column(
          children: [
            _HistoryToolbar(
              controller: _searchController,
              hintText: 'Search customer, date, or receipt ID',
              sort: _sort,
              sortItems: const {
                'latest': 'Latest',
                'oldest': 'Oldest',
                'a-z': 'Customer A-Z',
                'z-a': 'Customer Z-A',
              },
              onSearch: (value) =>
                  setState(() => _searchTerm = value.trim().toLowerCase()),
              onSort: (value) => setState(() => _sort = value),
              action: null,
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No transaction recorded'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _transactionRow(filtered[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  bool _matches(DocumentSnapshot<Map<String, dynamic>> sale) {
    final data = sale.data() ?? {};
    final date = _dateValue(data['saleDate']);
    return [
      data['salesId'],
      data['customerName'],
      date == null ? '' : _dateLabel(date),
    ].join(' ').toLowerCase().contains(_searchTerm);
  }

  int _compareSales(
    DocumentSnapshot<Map<String, dynamic>> a,
    DocumentSnapshot<Map<String, dynamic>> b,
    String sort,
  ) {
    final aData = a.data() ?? {};
    final bData = b.data() ?? {};
    if (sort == 'a-z' || sort == 'z-a') {
      final result = (aData['customerName'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((bData['customerName'] ?? '').toString().toLowerCase());
      return sort == 'a-z' ? result : -result;
    }
    final aDate =
        _dateValue(aData['saleDate']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bDate =
        _dateValue(bData['saleDate']) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final result = aDate.compareTo(bDate);
    return sort == 'oldest' ? result : -result;
  }

  Widget _transactionRow(DocumentSnapshot<Map<String, dynamic>> sale) {
    final data = sale.data() ?? {};
    final date = _dateValue(data['saleDate']);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: sale.reference.collection('items').snapshots(),
      builder: (context, snapshot) {
        final quantity = snapshot.data?.docs.fold<double>(
          0,
          (total, item) => total + _number(item.data()['quantity']),
        );
        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () => _showTransaction(sale),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 7,
            ),
            leading: const CircleAvatar(
              child: Icon(Icons.receipt_long_outlined),
            ),
            title: Text(
              data['customerName']?.toString() ?? 'Walk-in customer',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${data['salesId'] ?? 'Receipt ID not recorded'}  •  ${date == null ? 'Date not recorded' : _dateLabel(date)}',
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'PHP ${_money(_number(data['totalAmount']))}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  quantity == null
                      ? 'Qty loading...'
                      : 'Qty sold ${_money(quantity)}',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTransaction(DocumentSnapshot<Map<String, dynamic>> sale) {
    showDialog<void>(
      context: context,
      builder: (_) => _TransactionDetailsDialog(sale: sale),
    );
  }
}

class _CustomerBalanceHistoryView extends StatefulWidget {
  const _CustomerBalanceHistoryView();

  @override
  State<_CustomerBalanceHistoryView> createState() =>
      _CustomerBalanceHistoryViewState();
}

class _CustomerBalanceHistoryViewState
    extends State<_CustomerBalanceHistoryView> {
  final _searchController = TextEditingController();
  String _searchTerm = '';
  String _sort = 'latest';
  String _activityFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payments = FirebaseService().getFirestore().collection('payments');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: payments.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _error('Could not load balance history.\n${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final records = snapshot.data!.docs.toList()
          ..sort((a, b) => _comparePayments(a, b, _sort));
        final filtered = records.where((payment) {
          final data = payment.data();
          final date = _dateValue(data['paymentDate']);
          final activity = data['activityType']?.toString() ?? 'balance_paid';
          final matchesFilter =
              _activityFilter == 'all' || activity == _activityFilter;
          return matchesFilter &&
              [
                data['customerName'],
                data['method'],
                date == null ? '' : _dateLabel(date),
              ].join(' ').toLowerCase().contains(_searchTerm);
        }).toList();
        return Column(
          children: [
            _HistoryToolbar(
              controller: _searchController,
              hintText: 'Search customer or payment date',
              sort: _sort,
              sortItems: const {'latest': 'Latest', 'oldest': 'Oldest'},
              onSearch: (value) =>
                  setState(() => _searchTerm = value.trim().toLowerCase()),
              onSort: (value) => setState(() => _sort = value),
              action: _ActivityFilter(
                value: _activityFilter,
                onChanged: (value) => setState(() => _activityFilter = value),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No balance history'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _balanceRow(filtered[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  int _comparePayments(
    DocumentSnapshot<Map<String, dynamic>> a,
    DocumentSnapshot<Map<String, dynamic>> b,
    String sort,
  ) {
    final aDate =
        _dateValue((a.data() ?? {})['paymentDate']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final bDate =
        _dateValue((b.data() ?? {})['paymentDate']) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final result = aDate.compareTo(bDate);
    return sort == 'oldest' ? result : -result;
  }

  Widget _balanceRow(DocumentSnapshot<Map<String, dynamic>> payment) {
    final data = payment.data() ?? {};
    final date = _dateValue(data['paymentDate']);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => _showPayment(payment),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.shade50,
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.orange.shade800,
          ),
        ),
        title: Text(
          data['customerName']?.toString() ?? 'Customer balance activity',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${data['activityType'] == 'balance_created' ? 'Balance created' : 'Balance paid'}  •  ${date == null ? 'Date not recorded' : _dateLabel(date)}',
        ),
        trailing: Text(
          'PHP ${_money(_number(data['amount']))}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _showPayment(DocumentSnapshot<Map<String, dynamic>> payment) {
    final data = payment.data() ?? {};
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['customerName']?.toString() ?? 'Balance activity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _detail(
              'Activity date',
              _dateLabel(_dateValue(data['paymentDate'])),
            ),
            _detail('Payment method', '${data['method'] ?? '-'}'),
            _detail('Amount paid', 'PHP ${_money(_number(data['amount']))}'),
            _detail('Notes', '${data['notes'] ?? '-'}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ActivityFilter extends StatelessWidget {
  const _ActivityFilter({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: const InputDecoration(
          labelText: 'Activity',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'all', child: Text('All activity')),
          DropdownMenuItem(
            value: 'balance_created',
            child: Text('Balance created'),
          ),
          DropdownMenuItem(value: 'balance_paid', child: Text('Balance paid')),
        ],
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _HistoryToolbar extends StatelessWidget {
  const _HistoryToolbar({
    required this.controller,
    required this.hintText,
    required this.sort,
    required this.sortItems,
    required this.onSearch,
    required this.onSort,
    required this.action,
  });

  final TextEditingController controller;
  final String hintText;
  final String sort;
  final Map<String, String> sortItems;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSort;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sortControl = SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              initialValue: sort,
              decoration: const InputDecoration(
                labelText: 'Sort by',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final entry in sortItems.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                if (value != null) onSort(value);
              },
            ),
          );
          final search = TextField(
            controller: controller,
            onChanged: onSearch,
            decoration: InputDecoration(
              labelText: hintText,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          if (constraints.maxWidth < 620) {
            return Column(
              children: [
                search,
                const SizedBox(height: 10),
                Row(
                  children: [
                    sortControl,
                    if (action != null) ...[
                      const SizedBox(width: 10),
                      Expanded(child: action!),
                    ],
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              sortControl,
              if (action != null) ...[const SizedBox(width: 12), action!],
            ],
          );
        },
      ),
    );
  }
}

class _TransactionDetailsDialog extends StatelessWidget {
  const _TransactionDetailsDialog({required this.sale});

  final DocumentSnapshot<Map<String, dynamic>> sale;

  @override
  Widget build(BuildContext context) {
    final data = sale.data() ?? {};
    final items = sale.reference.collection('items');
    final narrow = MediaQuery.sizeOf(context).width < 760;
    final summary = AlertDialog(
      title: Text(data['customerName']?.toString() ?? 'Transaction details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _detail('Receipt ID', '${data['salesId'] ?? 'Not recorded'}'),
            _detail(
              'Transaction date',
              _dateLabel(_dateValue(data['saleDate'])),
            ),
            _detail('Payment status', '${data['paymentStatus'] ?? '-'}'),
            _detail(
              'Total amount',
              'PHP ${_money(_number(data['totalAmount']))}',
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Close'),
        ),
      ],
    );
    final itemsPanel = _ItemsPanel(items: items);
    if (narrow) {
      return Dialog(
        child: SingleChildScrollView(
          child: Column(
            children: [
              summary,
              SizedBox(height: 420, child: itemsPanel),
            ],
          ),
        ),
      );
    }
    return Dialog(
      child: SizedBox(
        width: 900,
        height: 560,
        child: Row(
          children: [
            Expanded(child: summary),
            const VerticalDivider(width: 1),
            Expanded(child: itemsPanel),
          ],
        ),
      ),
    );
  }
}

class _ItemsPanel extends StatelessWidget {
  const _ItemsPanel({required this.items});
  final CollectionReference<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: Text(
            'Purchased items',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: items.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Could not load items.\n${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No purchased items recorded'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = snapshot.data!.docs[index].data();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(data['productName']?.toString() ?? 'Product'),
                    subtitle: Text(
                      '${data['quantity'] ?? 0} ${data['unit'] ?? 'unit'}',
                    ),
                    trailing: Text('PHP ${_money(_number(data['lineTotal']))}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

Widget _detail(String label, String value) => ListTile(
  dense: true,
  contentPadding: EdgeInsets.zero,
  title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
  trailing: Text(value, textAlign: TextAlign.right),
);
Widget _error(String message) =>
    Center(child: Text(message, textAlign: TextAlign.center));
double _number(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
DateTime? _dateValue(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

String _dateLabel(DateTime? value) => value == null
    ? 'Date not recorded'
    : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String _money(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);
