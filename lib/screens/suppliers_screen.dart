import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final _firebaseService = FirebaseService();
  final _searchController = TextEditingController();
  String _searchTerm = '';

  CollectionReference<Map<String, dynamic>> get _suppliers =>
      _firebaseService.getFirestore().collection('suppliers');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_firebaseService.isInitialized) {
      return const Center(child: Text('Firebase is not initialized'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _suppliers.orderBy('companyName').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load suppliers.\n${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final suppliers = snapshot.data!.docs.where((supplier) {
          final data = supplier.data();
          final searchable = [
            data['companyName'],
            data['contactPerson'],
            data['phoneNumber'],
          ].join(' ').toLowerCase();
          return searchable.contains(_searchTerm);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(
                        () => _searchTerm = value.trim().toLowerCase(),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Search suppliers',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchTerm.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchTerm = '');
                                },
                                icon: const Icon(Icons.clear),
                              ),
                        filled: true,
                        fillColor: Colors.indigo.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () => _openSupplierForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add supplier'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: suppliers.isEmpty
                  ? Center(
                      child: Text(
                        _searchTerm.isEmpty
                            ? 'No suppliers yet'
                            : 'No matching suppliers',
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: suppliers.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _supplierCard(suppliers[index]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _supplierCard(DocumentSnapshot<Map<String, dynamic>> supplier) {
    final data = supplier.data() ?? {};
    final company = data['companyName']?.toString() ?? 'Unnamed supplier';
    final contact = data['contactPerson']?.toString() ?? '-';
    final phone = data['phoneNumber']?.toString() ?? '-';
    final isActive = data['status']?.toString() != 'inactive';

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Colors.teal.shade50,
          child: const Icon(Icons.local_shipping_outlined, color: Colors.teal),
        ),
        title: Text(
          company,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        onTap: () => _showSupplier(supplier),
        subtitle: Text(
          '$contact  •  $phone',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Switch.adaptive(
              value: isActive,
              onChanged: (value) => _setSupplierStatus(supplier, value),
              thumbIcon: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const Icon(Icons.check, size: 14)
                    : const Icon(Icons.close, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupplier(DocumentSnapshot<Map<String, dynamic>> supplier) {
    final data = supplier.data() ?? {};
    final isActive = data['status']?.toString() != 'inactive';
    final details = <String, String>{
      'Company name': '${data['companyName'] ?? '-'}',
      'Contact person': '${data['contactPerson'] ?? '-'}',
      'Phone number': '${data['phoneNumber'] ?? '-'}',
      'Email': '${data['email'] ?? '-'}',
      'Payment terms': '${data['paymentTerms'] ?? '-'}',
      'Notes': '${data['notes'] ?? '-'}',
    };
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(data['companyName']?.toString() ?? 'Supplier details'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              children: [
                ...details.entries.map(
                  (entry) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: SizedBox(
                      width: 230,
                      child: Text(entry.value, textAlign: TextAlign.right),
                    ),
                  ),
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  title: Text(
                    isActive ? 'Active supplier' : 'Inactive supplier',
                  ),
                  onChanged: (value) async {
                    await _setSupplierStatus(supplier, value);
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
              _deleteSupplier(supplier);
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
              _openSupplierForm(supplier);
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSupplierForm([
    DocumentSnapshot<Map<String, dynamic>>? supplier,
  ]) async {
    final data = supplier?.data() ?? {};
    final company = TextEditingController(
      text: data['companyName']?.toString(),
    );
    final contact = TextEditingController(
      text: data['contactPerson']?.toString(),
    );
    final phone = TextEditingController(text: data['phoneNumber']?.toString());
    final email = TextEditingController(text: data['email']?.toString());
    final terms = TextEditingController(text: data['paymentTerms']?.toString());
    final notes = TextEditingController(text: data['notes']?.toString());

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(supplier == null ? 'Add supplier' : 'Edit supplier'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _field(company, 'Company name', required: true),
                  _field(contact, 'Contact person', required: true),
                  _field(phone, 'Phone number', required: true),
                  _field(email, 'Email'),
                  _field(terms, 'Payment terms'),
                  _field(notes, 'Notes', maxLines: 3),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if ([
                  company,
                  contact,
                  phone,
                ].any((controller) => controller.text.trim().isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Complete the required fields'),
                    ),
                  );
                  return;
                }
                final record = {
                  'companyName': company.text.trim(),
                  'contactPerson': contact.text.trim(),
                  'phoneNumber': phone.text.trim(),
                  'email': email.text.trim(),
                  'paymentTerms': terms.text.trim(),
                  'notes': notes.text.trim(),
                  'updatedAt': FieldValue.serverTimestamp(),
                };
                try {
                  if (supplier == null) {
                    await _suppliers.add({
                      ...record,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  } else {
                    await supplier.reference.update(record);
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not save supplier: $error'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save supplier'),
            ),
          ],
        ),
      ),
    );
    for (final controller in [company, contact, phone, email, terms, notes]) {
      controller.dispose();
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _setSupplierStatus(
    DocumentSnapshot<Map<String, dynamic>> supplier,
    bool isActive,
  ) async {
    try {
      await supplier.reference.update({
        'status': isActive ? 'active' : 'inactive',
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update supplier status: $error')),
      );
    }
  }

  Future<void> _deleteSupplier(
    DocumentSnapshot<Map<String, dynamic>> supplier,
  ) async {
    final name = supplier.data()?['companyName'] ?? 'this supplier';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete supplier?'),
        content: Text('This will remove $name from supplier records.'),
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
    if (confirmed == true) await supplier.reference.delete();
  }
}
