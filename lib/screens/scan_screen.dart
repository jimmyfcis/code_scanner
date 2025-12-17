import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/io_client.dart';

import 'package:mobile_scanner/mobile_scanner.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

enum AttendStatus { idle, loading, success, error }

class _ScanScreenState extends State<ScanScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _scannerController;

  bool cameraStarted = false;
  String? scannedEmployeeId;
  String? errorMessage;

  AttendStatus status = AttendStatus.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scannerController = MobileScannerController(autoStart: false);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed &&
        scannedEmployeeId == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    if (cameraStarted) return;
    try {
      await _scannerController.start();
      cameraStarted = true;
    } catch (_) {}
  }

  Future<void> _stopCamera() async {
    if (!cameraStarted) return;
    try {
      await _scannerController.stop();
      cameraStarted = false;
    } catch (_) {}
  }

  void reset() async {
    setState(() {
      scannedEmployeeId = null;
      status = AttendStatus.idle;
      errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    _startCamera();
  }

  // ================= API CALL =================
  Future<void> attendEmployee(String employeeId) async {
    setState(() {
      status = AttendStatus.loading;
      errorMessage = null;
    });

    try {
      final httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

      final ioClient = IOClient(httpClient);

      final uri = Uri.parse(
        'https://192.168.54.200:1990/api/RSVP/attend?employeeId=$employeeId',
      );

      final response = await ioClient.post(uri);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['employeeId'] != null) {
        setState(() => status = AttendStatus.success);
      } else {
        setState(() {
          status = AttendStatus.error;
          errorMessage = data['errorMessage'] ?? 'Unknown error';
        });
      }

      ioClient.close();
    } catch (e) {
      setState(() {
        status = AttendStatus.error;
        errorMessage = 'Something went wrong';
      });
    }
  }


  void showResultDialog(String employeeId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.blueGrey[50],
            title: const Text('Employee Scanned'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  employeeId,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                if (status == AttendStatus.loading)
                  const CircularProgressIndicator(),

                if (status == AttendStatus.success)
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 64),

                if (status == AttendStatus.error) ...[
                  const Icon(Icons.error,
                      color: Colors.red, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],

                const SizedBox(height: 16),

                if (status == AttendStatus.idle)
                  ElevatedButton(
                    onPressed: () async {
                      setDialogState(() {});
                      await attendEmployee(employeeId);
                      setDialogState(() {});
                    },
                    child: const Text(
                      'Attend Employee',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                if (status == AttendStatus.success ||
                    status == AttendStatus.error)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      reset();
                    },
                    child: const Text(
                      'Scan Next',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[50],
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[50],
        title: const Text('Scan QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: reset,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (scannedEmployeeId == null)
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) async {
                final rawValue = capture.barcodes.first.rawValue;
                if (rawValue == null) return;

                final employeeId = extractEmployeeId(rawValue);
                if (employeeId.isEmpty) return;

                await _stopCamera();
                setState(() => scannedEmployeeId = employeeId);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showResultDialog(employeeId);
                });
              },
            ),
          if (scannedEmployeeId == null)
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Scan an employee QR code'),
              ),
            ),
        ],
      ),
    );
  }
}

// ================= HELPERS =================
String extractEmployeeId(String qrData) {
  final regex = RegExp(r'EmployeeId:\s*([^,]+)');
  return regex.firstMatch(qrData)?.group(1)?.trim() ?? '';
}
