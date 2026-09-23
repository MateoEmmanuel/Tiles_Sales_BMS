import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'screens/office_shell.dart';

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
      home: const OfficeShell(),
    );
  }
}
