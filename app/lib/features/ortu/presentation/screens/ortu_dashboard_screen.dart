import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import 'verifikasi_ortu_screen.dart';
import 'pengajuan_izin_screen.dart';

class OrtuDashboardScreen extends ConsumerStatefulWidget {
  const OrtuDashboardScreen({super.key});

  @override
  ConsumerState<OrtuDashboardScreen> createState() => _OrtuDashboardScreenState();
}

class _OrtuDashboardScreenState extends ConsumerState<OrtuDashboardScreen> {
  String? _selectedAnakId;
  
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Jika belum punya anak yang diverifikasi
    if (user.anakIds == null || user.anakIds!.isEmpty) {
      return VerifikasiOrtuScreen(
        onVerificationComplete: () {
          // Akan merefresh stream AuthController jika diimplementasikan
          ref.invalidate(authControllerProvider);
        },
      );
    }

    // Default anak pertama
    _selectedAnakId ??= user.anakIds!.first;
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Orang Tua'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => ref.read(authControllerProvider.notifier).logout()),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dropdown Pilih Anak
            if (user.anakIds!.length > 1)
              DropdownButton<String>(
                value: _selectedAnakId,
                isExpanded: true,
                items: user.anakIds!.map((id) => DropdownMenuItem(value: id, child: Text('Anak ID: $id'))).toList(),
                onChanged: (val) => setState(() => _selectedAnakId = val),
              )
            else 
              Text('Data Absensi Anak', style: Theme.of(context).textTheme.titleLarge),
            
            const SizedBox(height: 24),
            
            // STREAM ABSENSI HARI INI
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('absensi').doc('$dateStr_$_selectedAnakId').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                
                if (data == null) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('Anak Anda belum absen hari ini.', textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                    ),
                  );
                }

                final status = data['status'].toString().toUpperCase();
                final lat = data['lokasi']['lat'];
                final lng = data['lokasi']['lng'];
                final jam = DateFormat('HH:mm').format((data['waktuScan'] as Timestamp).toDate());

                return Column(
                  children: [
                    Card(
                      color: Colors.blue.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.access_time, size: 40, color: Colors.blue),
                        title: Text('Status: $status'),
                        subtitle: Text('Jam Absen: $jam WIB'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Lokasi Absen:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(lat, lng),
                            initialZoom: 16.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(lat, lng),
                                  child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PengajuanIzinScreen(anakId: _selectedAnakId!))),
              icon: const Icon(Icons.edit_document),
              label: const Text('Ajukan Izin / Sakit'),
            ),
          ],
        ),
      ),
    );
  }
}
