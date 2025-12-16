import 'dart:math';
import 'package:flutter/material.dart';
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
  bool cameraStarted = false; // Track camera manually

  String? scannedEmployeeId;
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
      if (cameraStarted) _scannerController.stop();
    } else if (state == AppLifecycleState.resumed && scannedEmployeeId == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    if (cameraStarted) return;
    try {
      await _scannerController.start();
      cameraStarted = true;
    } catch (_) {
      // Ignore errors if camera is busy
    }
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
    });

    await Future.delayed(const Duration(milliseconds: 300));
    _startCamera();
  }

  // ---------------- SIMULATED ATTEND API ----------------
  Future<void> attendEmployee() async {
    setState(() => status = AttendStatus.loading);

    await Future.delayed(const Duration(seconds: 2));

    final bool isSuccess = Random().nextBool();

    if (!mounted) return;
    setState(() {
      status = isSuccess ? AttendStatus.success : AttendStatus.error;
    });
  }

  void showResultDialog(String employeeId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Employee Scanned'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(employeeId,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              if (status == AttendStatus.loading)
                const CircularProgressIndicator(),
              if (status == AttendStatus.success)
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
              if (status == AttendStatus.error)
                const Icon(Icons.error, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              if (status == AttendStatus.idle)
                ElevatedButton(
                  onPressed: () async {
                    setDialogState(() {
                      status = AttendStatus.loading;
                    });
                    await attendEmployee();
                    setDialogState(() {});
                  },
                  child: const Text('Attend Employee'),
                ),
              if (status == AttendStatus.success || status == AttendStatus.error)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    reset();
                  },
                  child: const Text('Scan Next'),
                ),
            ],
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;

                final rawValue = barcodes.first.rawValue;
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
                child: Text(
                  'Scan an employee QR code',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------- HELPERS ----------------
String extractEmployeeId(String qrData) {
  final regex = RegExp(r'EmployeeId:\s*([^,]+)');
  final match = regex.firstMatch(qrData);
  return match?.group(1)?.trim() ?? '';
}
