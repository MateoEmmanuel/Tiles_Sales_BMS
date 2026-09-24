import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

/// Connection Status Screen - Displays Firebase connection status and errors
class ConnectionStatusScreen extends StatefulWidget {
  const ConnectionStatusScreen({super.key});

  @override
  State<ConnectionStatusScreen> createState() => _ConnectionStatusScreenState();
}

class _ConnectionStatusScreenState extends State<ConnectionStatusScreen> {
  late FirebaseService _firebaseService;
  final List<String> _errors = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _setupErrorListener();
  }

  void _setupErrorListener() {
    _firebaseService.errors.listen((error) {
      setState(() {
        _errors.add('${DateTime.now().toIso8601String()}: $error');
        // Keep only last 50 errors to avoid memory issues
        if (_errors.length > 50) {
          _errors.removeAt(0);
        }
      });
      // Auto-scroll to latest error
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  Future<void> _refreshConnection() async {
    setState(() {
      _errors.clear();
    });
    try {
      await _firebaseService.initialize();
    } catch (e) {
      // Error will be added via the stream listener
    }
  }

  void _clearErrors() {
    setState(() {
      _errors.clear();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Connection Status'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          // Status Header
          _buildStatusHeader(),

          // Divider
          const Divider(height: 1),

          // Errors/Logs Section
          Expanded(child: _buildErrorsSection()),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    return StreamBuilder<bool>(
      stream: _firebaseService.connectionStatus,
      initialData: _firebaseService.isConnected,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? false;
        final isInitialized = _firebaseService.isInitialized;

        return Container(
          padding: const EdgeInsets.all(20),
          color: isInitialized ? Colors.grey[100] : Colors.orange[50],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Initialization Status
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isInitialized ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isInitialized ? '✓ Initialized' : '⏳ Initializing...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isInitialized ? Colors.green : Colors.orange[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Connection Status
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isConnected
                          ? '✓ Connected to Firestore'
                          : '✗ Disconnected from Firestore',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isConnected
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),

              if (!isInitialized)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text(
                    'Please ensure Firebase is configured in firebase_options.dart',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
          child: Text(
            'Connection Logs & Errors (${_errors.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: _errors.isEmpty
              ? Center(
                  child: Text(
                    'No errors or logs yet\nConnection status will appear here',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _errors.length,
                  itemBuilder: (context, index) {
                    final error = _errors[index];
                    final isError = error.contains('ERROR');
                    final isInfo = error.contains('INFO');

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isError
                            ? Colors.red[50]
                            : isInfo
                            ? Colors.blue[50]
                            : Colors.yellow[50],
                        border: Border(
                          left: BorderSide(
                            color: isError
                                ? Colors.red
                                : isInfo
                                ? Colors.blue
                                : Colors.orange,
                            width: 3,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        error,
                        style: TextStyle(
                          fontSize: 12,
                          color: isError
                              ? Colors.red[700]
                              : isInfo
                              ? Colors.blue[700]
                              : Colors.orange[700],
                          fontFamily: 'Courier',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        color: Colors.grey[50],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: _refreshConnection,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _clearErrors,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear Logs'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
