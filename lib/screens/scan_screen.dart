import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();

  String? scannedData;
  bool isSubmitting = false;

  void reset() {
    setState(() {
      scannedData = null;
      isSubmitting = false;
    });

    _scannerController.start();
  }

  Future<void> attendEmployee(String employeeId) async {
    setState(() => isSubmitting = true);

    try {
      final uri = Uri.parse(
        'https://your-api.com/rsvp/attend?employeeId=$employeeId',
      );

      final response = await http.post(uri);

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance successful')),
        );

      } else {
        throw Exception('Failed with status ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    reset();
  }

  void showResultDialog(String employeeId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Scanned Employee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(employeeId, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            isSubmitting
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: () => attendEmployee(employeeId),
              child: const Text('Attend Employee'),
            ),
          ],
        ),
      ),
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
          )
        ],
      ),
      body: Stack(
        children: [
          if (scannedData == null)
            MobileScanner(
              controller: _scannerController,
              onDetect: (BarcodeCapture capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;

                final value = barcodes.first.rawValue;
                if (value == null) return;

                _scannerController.stop();

                setState(() => scannedData = value);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                 String employeeId =extractEmployeeId(value);
                  showResultDialog(employeeId);
                });
              },
            ),

          if (scannedData == null)
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Scan a QR code'),
              ),
            ),
        ],
      ),
    );
  }
}
String extractEmployeeId(String qrData) {
  final regex = RegExp(r'EmployeeId:\s*([^,]+)');
  final match = regex.firstMatch(qrData);
  return match?.group(1)?.trim() ?? '';
}