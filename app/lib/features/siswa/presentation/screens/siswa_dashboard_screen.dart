import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import 'scanner_screen.dart';

class SiswaDashboardScreen extends ConsumerWidget {
  const SiswaDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final displayDate = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now());

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Stream untuk mengecek status absen hari ini (real-time)
    final absenHariIniStream = FirebaseFirestore.instance
        .collection('absensi')
        .doc('$dateStr_$ {user.uid}')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Siswa'),
        actions: [
          IconButton(icon: const Icon(Icons.bug_report), onPressed: () {}), // Laporkan bug
          IconButton(icon: const Icon(Icons.logout), onPressed: () => ref.read(authControllerProvider.notifier).logout()),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HEADER
            Text(user.nama, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('Kelas: $ {user.kelasId ?? '-'}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(displayDate, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // KARTU STATUS HARI INI
            StreamBuilder<DocumentSnapshot>(
              stream: absenHariIniStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Error memuat status.')));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final sudahAbsen = data != null;
                final status = data?['status']?.toString().toUpperCase() ?? 'BELUM ABSEN';
                final color = _getStatusColor(status);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: color.withOpacity(0.1),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: color, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Text('Status Hari Ini', style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(status, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // TOMBOL SCAN QR
                    ElevatedButton.icon(
                      onPressed: sudahAbsen 
                          ? null 
                          : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())),
                      icon: const Icon(Icons.qr_code_scanner, size: 32),
                      label: const Text('Scan QR Absen', style: TextStyle(fontSize: 18)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: sudahAbsen ? Colors.grey : Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                );
              }
            ),
            const SizedBox(height: 32),

            // RIWAYAT ABSEN (Simple List)
            const Text('Riwayat Absen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('absensi')
                  .where('siswaId', isEqualTo: user.uid)
                  .orderBy('tanggal', descending: true)
                  .limit(7)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Text('Belum ada riwayat absensi.');

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final status = data['status'].toString().toUpperCase();
                    return Card(
                      child: ListTile(
                        title: Text(data['tanggal']),
                        trailing: Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(status))),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'HADIR': return Colors.green;
      case 'TERLAMBAT': return Colors.orange;
      case 'IZIN': return Colors.blue;
      case 'SAKIT': return Colors.purple;
      case 'ALPHA': return Colors.red;
      default: return Colors.grey;
    }
  }
}
