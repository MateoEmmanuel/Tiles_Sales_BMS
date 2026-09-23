import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'sales_screen.dart';
import 'suppliers_screen.dart';

class OfficeShell extends StatefulWidget {
  const OfficeShell({super.key});

  @override
  State<OfficeShell> createState() => _OfficeShellState();
}

class _OfficeShellState extends State<OfficeShell> {
  final _firebaseService = FirebaseService();
  int _selectedIndex = 0;

  static const _destinations = [
    _OfficeDestination('Overview', Icons.dashboard_outlined),
    _OfficeDestination('Products', Icons.inventory_2_outlined),
    _OfficeDestination('Sales', Icons.point_of_sale_outlined),
    _OfficeDestination('Suppliers', Icons.local_shipping_outlined),
    _OfficeDestination('Reports', Icons.bar_chart_outlined),
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
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 8,
        leadingWidth: 280,
        leading: _BusinessBrand(settings: settings),
        title: _buildQuickNavigation(),
        actions: [_buildUserMenu(), const SizedBox(width: 8)],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const ProductsScreen(
            showAppBar: false,
            showFloatingActions: false,
            showDashboard: true,
            showProductList: false,
          ),
          const ProductsScreen(
            showAppBar: false,
            showDashboard: false,
            showProductList: true,
          ),
          const SalesScreen(),
          const SuppliersScreen(),
          const ReportsScreen(),
        ],
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
            _destinations[_selectedIndex].label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          PopupMenuButton<int>(
            tooltip: 'Quick navigation',
            onSelected: _selectDestination,
            icon: const Icon(Icons.menu_open),
            itemBuilder: (context) => [
              for (var index = 0; index < _destinations.length; index++)
                PopupMenuItem(
                  value: index,
                  child: ListTile(
                    dense: true,
                    leading: Icon(_destinations[index].icon),
                    title: Text(_destinations[index].label),
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
            onPressed: () => _selectDestination(index),
            icon: Icon(_destinations[index].icon, size: 17),
            label: Text(_destinations[index].label),
            style: TextButton.styleFrom(
              foregroundColor: _selectedIndex == index
                  ? Colors.indigo
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
              backgroundColor: Colors.indigo.shade50,
              child: const Icon(
                Icons.person_outline,
                size: 19,
                color: Colors.indigo,
              ),
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

  void _selectDestination(int index) => setState(() => _selectedIndex = index);

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
    return Padding(
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
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
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
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(Icons.business_outlined, color: Colors.indigo)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.business_outlined, color: Colors.indigo),
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

class _OfficeDestination {
  const _OfficeDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}
