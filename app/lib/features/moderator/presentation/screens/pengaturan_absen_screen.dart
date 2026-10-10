import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PengaturanAbsenScreen extends StatefulWidget {
  const PengaturanAbsenScreen({super.key});

  @override
  State<PengaturanAbsenScreen> createState() => _PengaturanAbsenScreenState();
}

class _PengaturanAbsenScreenState extends State<PengaturanAbsenScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Nilai Default SMPN 9 Probolinggo
  LatLng _lokasiSekolah = const LatLng(-7.750, 113.210);
  double _radiusMeter = 100.0;
  TimeOfDay _batasTerlambat = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _jamAlpha = const TimeOfDay(hour: 10, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPengaturan();
  }

  Future<void> _loadPengaturan() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('pengaturan').doc('aplikasi').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _radiusMeter = (data['radiusMeter'] ?? 100).toDouble();
          _lokasiSekolah = LatLng(data['lokasiSekolah']['lat'], data['lokasiSekolah']['lng']);
          
          final bt = data['batasTerlambat']?.toString().split(':');
          if (bt != null) _batasTerlambat = TimeOfDay(hour: int.parse(bt[0]), minute: int.parse(bt[1]));
          
          final ja = data['jamAlpha']?.toString().split(':');
          if (ja != null) _jamAlpha = TimeOfDay(hour: int.parse(ja[0]), minute: int.parse(ja[1]));
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat pengaturan: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _simpan() async {
    setState(() => _isSaving = true);
    try {
      final btStr = '$ {_batasTerlambat.hour.toString().padLeft(2, '0')}:$ {_batasTerlambat.minute.toString().padLeft(2, '0')}:00';
      final jaStr = '$ {_jamAlpha.hour.toString().padLeft(2, '0')}:$ {_jamAlpha.minute.toString().padLeft(2, '0')}:00';

      await FirebaseFunctions.instance.httpsCallable('updatePengaturan').call({
        'batasTerlambat': btStr,
        'jamAlpha': jaStr,
        'radiusMeter': _radiusMeter,
        'latSekolah': _lokasiSekolah.latitude,
        'lngSekolah': _lokasiSekolah.longitude,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan berhasil diperbarui!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Absensi')),
      body: Column(
        children: [
          // MAP PENGATURAN LOKASI (GEOFENCE)
          Expanded(
            flex: 2,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _lokasiSekolah,
                initialZoom: 17.0,
                onTap: (tapPosition, point) => setState(() => _lokasiSekolah = point),
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _lokasiSekolah,
                      color: Colors.blue.withOpacity(0.3),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 2,
                      radius: _radiusMeter,
                      useRadiusInMeter: true,
                    )
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(point: _lokasiSekolah, child: const Icon(Icons.school, color: Colors.red, size: 40))
                  ],
                ),
              ],
            ),
          ),
          
          // PANEL PENGATURAN
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('1. Atur Lokasi & Radius Sekolah', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text('Ketuk peta di atas untuk memindahkan titik sekolah.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Slider(
                    value: _radiusMeter,
                    min: 10, max: 500, divisions: 49,
                    label: '$ {_radiusMeter.toInt()} meter',
                    onChanged: (val) => setState(() => _radiusMeter = val),
                  ),
                  Text('Radius Toleransi Absen: $ {_radiusMeter.toInt()} meter', textAlign: TextAlign.center),
                  const Divider(height: 32),
                  
                  const Text('2. Atur Jam Keterlambatan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ListTile(
                    title: const Text('Batas Terlambat (Setelah ini = Terlambat)'),
                    trailing: Text(_batasTerlambat.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _batasTerlambat);
                      if (t != null) setState(() => _batasTerlambat = t);
                    },
                  ),
                  ListTile(
                    title: const Text('Jam Alpha (Setelah ini = Ditolak)'),
                    trailing: Text(_jamAlpha.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: _jamAlpha);
                      if (t != null) setState(() => _jamAlpha = t);
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    onPressed: _isSaving ? null : _simpan,
                    child: _isSaving ? const CircularProgressIndicator() : const Text('Simpan Pengaturan'),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
