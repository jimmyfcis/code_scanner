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

enum DetailsStatus { idle, loading, success, error }

enum MainDishType { seafood, beefOrChicken }

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late final MobileScannerController _scannerController;

  bool cameraStarted = false;
  String? scannedEmployeeId;
  String? errorMessage;
  String? employeeName;
  String? employeeEmail;
  MainDishType? mainDish;

  AttendStatus attendStatus = AttendStatus.idle;
  DetailsStatus detailsStatus = DetailsStatus.idle;

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

  MainDishType? parseMainDish(int? value) {
    switch (value) {
      case 1:
        return MainDishType.seafood;
      case 2:
        return MainDishType.beefOrChicken;
      default:
        return null;
    }
  }

  String mainDishLabel(MainDishType? type) {
    switch (type) {
      case MainDishType.seafood:
        return 'Seafood 🐟';
      case MainDishType.beefOrChicken:
        return 'Beef / Chicken 🥩';
      default:
        return '';
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
      attendStatus = AttendStatus.idle;
      detailsStatus = DetailsStatus.idle;
      errorMessage = null;
      employeeName = null;
      employeeEmail = null;
      mainDish = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    _startCamera();
  }

  void resetWithoutCamera() async {
    setState(() {
      scannedEmployeeId = null;
      attendStatus = AttendStatus.idle;
      detailsStatus = DetailsStatus.idle;
      errorMessage = null;
      employeeName = null;
      employeeEmail = null;
      mainDish = null;
    });
  }

  // ================= API CALL =================
  Future<void> attendEmployee(String employeeId) async {
    setState(() {
      attendStatus = AttendStatus.loading;
      errorMessage = null;
    });

    try {
      final httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

      final ioClient = IOClient(httpClient);

      final uri = Uri.parse(
        'https://apiattendance.flairstech.com/api/RSVP/attend?employeeId=$employeeId',
      );

      final response = await ioClient.post(uri);

      final data = jsonDecode(response.body);
      resetWithoutCamera();
      if (response.statusCode == 200 && data['employeeId'] != null) {
        setState(() {
          attendStatus = AttendStatus.success;
          employeeName = data['employeeName'];
          employeeEmail = data['email'];
          mainDish = parseMainDish(data['mainDish']);
        });
      } else {
        setState(() {
          attendStatus = AttendStatus.error;
          errorMessage = data['errorMessage'] ?? 'Unknown error';
        });
      }

      ioClient.close();
    } catch (e) {
      setState(() {
        attendStatus = AttendStatus.error;
        errorMessage = 'Something went wrong';
      });
    }
  }

  Future<void> viewEmployee(String employeeId) async {
    setState(() {
      detailsStatus = DetailsStatus.loading;
      errorMessage = null;
    });

    try {
      final httpClient = HttpClient()
        ..badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;

      final ioClient = IOClient(httpClient);

      final uri = Uri.parse(
        'https://apiattendance.flairstech.com/api/RSVP/attend?employeeId=$employeeId',
      );

      final response = await ioClient.get(uri);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['employeeId'] != null) {
        setState(() {
          detailsStatus = DetailsStatus.success;
          employeeName = data['employeeName'];
          employeeEmail = data['email'];
          mainDish = parseMainDish(data['mainDish']);
        });
      } else {
        setState(() {
          detailsStatus = DetailsStatus.error;
          errorMessage = data['errorMessage'] ?? 'Unknown error';
        });
      }

      ioClient.close();
    } catch (e) {
      setState(() {
        detailsStatus = DetailsStatus.error;
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (attendStatus == AttendStatus.loading)
                  const CircularProgressIndicator(),

                if (attendStatus == AttendStatus.success) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    employeeName ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    employeeEmail ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mainDishLabel(mainDish),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "$employeeName attended successfully",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
                if (attendStatus == AttendStatus.error) ...[
                  const Icon(Icons.cancel, color: Colors.red, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      reset();
                    },
                    child: const Text(
                      'Scan More',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(color: Color(0xFFD13827)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      reset();
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFFD13827)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void showDetailsDialog(String employeeId) {
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (detailsStatus == DetailsStatus.loading)
                  const CircularProgressIndicator(),

                if (detailsStatus == DetailsStatus.success) ...[
                  const Icon(Icons.person, color: Colors.grey, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    employeeName ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    employeeEmail ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mainDishLabel(mainDish),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await attendEmployee(employeeId);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          showResultDialog(employeeId);
                        });
                      },
                      child: const Text(
                        'Confirm',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: Color(0xFFD13827)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        reset();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Color(0xFFD13827)),
                      ),
                    ),
                  ),
                ],
                if (detailsStatus == DetailsStatus.error) ...[
                  const Icon(Icons.cancel, color: Colors.red, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        reset();
                      },
                      child: const Text(
                        'Retry',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: reset),
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
                await viewEmployee(employeeId);
                setState(() => scannedEmployeeId = employeeId);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showDetailsDialog(employeeId);
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
