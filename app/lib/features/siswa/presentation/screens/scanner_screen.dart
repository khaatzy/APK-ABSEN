import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrData = barcodes.first.rawValue;
    if (qrData == null) return;

    setState(() => _isProcessing = true);
    _cameraController.pause();

    try {
      // 1. Cek Permission GPS
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Izin lokasi ditolak. Wajib untuk absen.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi ditolak permanen. Buka pengaturan HP Anda.');
      }

      // 2. Ambil Lokasi (Akurasi Tinggi)
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Cek Mock Location (Anti Fake GPS)
      if (position.isMocked) {
        throw Exception('Aplikasi Fake GPS terdeteksi! Absen ditolak.');
      }

      // 3. Panggil Cloud Function
      showDialog(
        context: context, 
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      final result = await FirebaseFunctions.instance.httpsCallable('submitAttendance').call({
        'qrPayload': qrData,
        'lat': position.latitude,
        'lng': position.longitude,
        'akurasi': position.accuracy,
      });

      if (mounted) Navigator.pop(context); // Tutup loading

      if (result.data['success'] == true) {
        if (mounted) {
          await showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Absen Berhasil ?'),
              content: Text('Status: $ {result.data['status'].toString().toUpperCase()}\nJam: $ {result.data['waktu']}'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(c); // Tutup alert
                    Navigator.pop(context); // Tutup scanner, kembali ke dashboard
                  },
                  child: const Text('OK'),
                )
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context); // Pastikan loading tertutup
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Absen Gagal ?'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  _cameraController.start();
                  setState(() => _isProcessing = false);
                },
                child: const Text('Coba Lagi'),
              )
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Absen')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _handleBarcode,
          ),
          // Overlay Target Kotak
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Arahkan kamera ke QR Code milik Guru Piket',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, backgroundColor: Colors.black54, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
