import 'package:flutter/material.dart';
import 'admin/admin_shell.dart';
import 'admin/sample_data_page.dart';
import 'cashier/cashier_shell.dart';
import 'services/firebase_service.dart';
import 'office/office_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  final firebaseService = FirebaseService();
  try {
    await firebaseService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize Firebase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tiles Selling BMS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
      ),
      debugShowCheckedModeBanner: false,
      routes: {'/login': (_) => const LoginPage()},
      home: _workspaceForRole(),
    );
  }

  Widget _workspaceForRole() {
    const role = String.fromEnvironment('APP_ROLE', defaultValue: 'login');
    return switch (role) {
      'cashier' => const CashierShell(),
      'office' => const OfficeShell(),
      'admin' => const AdminShell(),
      'sample_data' => const SampleDataPage(),
      _ => const LoginPage(),
    };
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF176B6B),
      brightness: Brightness.light,
    );
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFFAF9F6),
      ),
      child: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.grid_view_rounded,
                          size: 30,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Tiles Selling BMS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose a workspace to continue.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 24),
                      _RoleButton(
                        icon: Icons.point_of_sale_outlined,
                        label: 'Cashier',
                        onPressed: () =>
                            _openWorkspace(context, const CashierShell()),
                      ),
                      const SizedBox(height: 10),
                      _RoleButton(
                        icon: Icons.business_center_outlined,
                        label: 'Office',
                        onPressed: () =>
                            _openWorkspace(context, const OfficeShell()),
                      ),
                      const SizedBox(height: 10),
                      _RoleButton(
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Admin',
                        onPressed: () =>
                            _openWorkspace(context, const AdminShell()),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Authentication is not connected yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openWorkspace(BuildContext context, Widget workspace) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: (_) => workspace));
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}
