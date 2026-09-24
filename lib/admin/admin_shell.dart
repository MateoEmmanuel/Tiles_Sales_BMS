import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _firebaseService = FirebaseService();
  int _selectedIndex = 0;

  static const _destinations = [
    ('Overview', Icons.dashboard_outlined),
    ('Staff', Icons.manage_accounts_outlined),
    ('Settings', Icons.settings_outlined),
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
          children: const [_AdminOverview(), _AdminStaff(), _AdminSettings()],
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

  Widget _buildUserMenu() => PopupMenuButton<String>(
    tooltip: 'Open staff profile',
    onSelected: (value) {
      if (value == 'profile') _showProfileDialog();
    },
    itemBuilder: (context) => const [
      PopupMenuItem(value: 'profile', child: Text('Staff information')),
      PopupMenuItem(
        enabled: false,
        value: 'status',
        child: Text('Role: administrator'),
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
  Widget build(BuildContext context) => Tooltip(
    message: 'Return to login page',
    child: InkWell(
      onTap: () =>
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: settings.logoUrl?.trim().isNotEmpty == true
                  ? Image.network(
                      settings.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.business_outlined),
                    )
                  : const Icon(Icons.business_outlined),
            ),
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

class _AdminOverview extends StatelessWidget {
  const _AdminOverview();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Administration overview',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'Manage access, configuration, and system health from a separate workspace.',
        style: TextStyle(color: Colors.grey.shade700),
      ),
      const SizedBox(height: 24),
      const Row(
        children: [
          Expanded(
            child: _AdminMetric(
              label: 'Staff accounts',
              value: '0',
              icon: Icons.people_outline,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _AdminMetric(
              label: 'Pending actions',
              value: '0',
              icon: Icons.pending_actions_outlined,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: _AdminMetric(
              label: 'System status',
              value: 'Ready',
              icon: Icons.check_circle_outline,
            ),
          ),
        ],
      ),
    ],
  );
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.indigo),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Text(label),
        ],
      ),
    ),
  );
}

class _AdminStaff extends StatelessWidget {
  const _AdminStaff();

  @override
  Widget build(BuildContext context) => const _AdminPlaceholder(
    title: 'Staff accounts',
    message:
        'Staff account management will be connected to Firebase Authentication and the users collection.',
    icon: Icons.manage_accounts_outlined,
  );
}

class _AdminSettings extends StatelessWidget {
  const _AdminSettings();

  @override
  Widget build(BuildContext context) => const _AdminPlaceholder(
    title: 'System settings',
    message:
        'Business settings, permissions, and system configuration belong in this workspace.',
    icon: Icons.settings_outlined,
  );
}

class _AdminPlaceholder extends StatelessWidget {
  const _AdminPlaceholder({
    required this.title,
    required this.message,
    required this.icon,
  });
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(icon, size: 46, color: Colors.indigo),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}
