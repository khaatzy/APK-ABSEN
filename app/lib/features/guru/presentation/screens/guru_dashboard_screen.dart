import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import '../providers/qr_provider.dart';
import 'wali_kelas_screen.dart';

class GuruDashboardScreen extends ConsumerStatefulWidget {
  const GuruDashboardScreen({super.key});

  @override
  ConsumerState<GuruDashboardScreen> createState() => _GuruDashboardScreenState();
}

class _GuruDashboardScreenState extends ConsumerState<GuruDashboardScreen> {
  bool _isResetting = false;

  @override
  void initState() {
    super.initState();
    // Cegah layar mati dan maksimalkan kecerahan
    WakelockPlus.enable();
    try {
      ScreenBrightness().setScreenBrightness(1.0);
    } catch (e) {
      debugPrint('Gagal mengatur kecerahan: $e');
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    try {
      ScreenBrightness().resetScreenBrightness();
    } catch (e) {}
    super.dispose();
  }

  Future<void> _resetQr() async {
    setState(() => _isResetting = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('resetQr').call();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR berhasil direset!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal reset QR: $e')));
    } finally {
      if (mounted) setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final tokenData = ref.watch(dailyQrProvider);
    final today = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now());
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now()); // Format database
    
    final isWaliKelas = user?.kelasId != null && user!.kelasId!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Guru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Selamat Datang,', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
              Text(user?.nama ?? 'Guru', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              
              // PANEL QR CODE
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const Text('QR Code Absensi Hari Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(today, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 24),
                      
                      tokenData.when(
                        loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                        error: (err, stack) => SizedBox(height: 200, child: Center(child: Text('Error: $err'))),
                        data: (token) {
                          if (token == null) return const SizedBox(height: 200, child: Center(child: Text('Menunggu QR...')));
                          
                          // Format JSON Ringkas sesuai spesifikasi Issue #4
                          final qrPayload = jsonEncode({"v": 1, "g": user?.uid, "t": token});
                          
                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.blue.shade200, width: 3),
                                ),
                                child: QrImageView(
                                  data: qrPayload,
                                  version: QrVersions.auto,
                                  size: 220.0,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _isResetting
                                  ? const CircularProgressIndicator()
                                  : OutlinedButton.icon(
                                      onPressed: _resetQr,
                                      icon: const Icon(Icons.refresh, color: Colors.red),
                                      label: const Text('Reset QR', style: TextStyle(color: Colors.red)),
                                    ),
                            ],
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // REALTIME DAFTAR SCAN
              const Text('Baru Saja Absen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (user != null)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('absensi')
                      .where('guruId', isEqualTo: user.uid)
                      .where('tanggal', isEqualTo: dateStr)
                      .orderBy('waktuScan', descending: true)
                      .limit(10)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return Text('Error memuat data: $ {snapshot.error}');
                    if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
                    
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) return const Text('Belum ada siswa yang absen lewat QR Anda hari ini.', style: TextStyle(color: Colors.grey));

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final waktu = data['waktuScan'] != null 
                            ? DateFormat('HH:mm').format((data['waktuScan'] as Timestamp).toDate()) 
                            : '--:--';
                        final status = data['status'];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Text(status == 'hadir' ? 'H' : 'T', style: TextStyle(color: status == 'hadir' ? Colors.green : Colors.orange))),
                            title: Text('Siswa ID: $ {data['siswaId']}'), // Sebaiknya join dgn collection users
                            subtitle: Text('Jam: $waktu'),
                            trailing: Text(status.toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                    );
                  }
                ),

              const SizedBox(height: 32),
              if (isWaliKelas)
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WaliKelasScreen())),
                  icon: const Icon(Icons.admin_panel_settings),
                  label: Text('Menu Wali Kelas ()'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
