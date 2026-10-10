import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../providers/wali_kelas_provider.dart';
import '../domain/wali_kelas_models.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class WaliKelasScreen extends ConsumerWidget {
  const WaliKelasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel Wali Kelas'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people), text: 'Siswa'),
              Tab(icon: Icon(Icons.verified_user), text: 'Verifikasi'),
              Tab(icon: Icon(Icons.sick), text: 'Izin/Sakit'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DaftarSiswaTab(),
            _VerifikasiOrtuTab(),
            _IzinSakitTab(),
          ],
        ),
      ),
    );
  }
}

class _DaftarSiswaTab extends ConsumerStatefulWidget {
  const _DaftarSiswaTab();
  @override
  ConsumerState<_DaftarSiswaTab> createState() => _DaftarSiswaTabState();
}

class _DaftarSiswaTabState extends ConsumerState<_DaftarSiswaTab> {
  bool _isImporting = false;
  String _importStatus = '';

  Future<void> _importExcel() async {
    final user = ref.read(authControllerProvider).value;
    if (user == null || user.kelasId == null) return;

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      setState(() {
        _isImporting = true;
        _importStatus = 'Membaca file...';
      });

      try {
        var fileBytes = result.files.first.bytes;
        if (fileBytes == null) {
          final file = File(result.files.first.path!);
          fileBytes = file.readAsBytesSync();
        }

        var excel = Excel.decodeBytes(fileBytes);
        var sheet = excel.tables[excel.tables.keys.first];
        
        if (sheet == null) throw Exception('Sheet kosong');

        int success = 0;
        int failed = 0;
        
        // Mulai dari baris ke-2 (index 1) asumsi baris 1 adalah Header
        for (int i = 1; i < sheet.maxRows; i++) {
          var row = sheet.row(i);
          if (row.isEmpty || row[0]?.value == null) continue;

          String nama = row[0]?.value.toString() ?? '';
          String nisn = row[1]?.value.toString() ?? '';
          String nis = row[2]?.value.toString() ?? '';
          String nik = row[3]?.value.toString() ?? '';

          // Validasi ketat sesuai Issue #4
          if (nisn.length == 10 && nik.length == 16) {
            try {
              setState(() => _importStatus = 'Mengimpor $nama...');
              await FirebaseFunctions.instance.httpsCallable('createSiswa').call({
                'nama': nama,
                'nisn': nisn,
                'nis': nis,
                'nik': nik,
                'kelasId': user.kelasId,
              });
              success++;
            } catch (e) {
              failed++;
            }
          } else {
            failed++;
          }
        }

        if (mounted) {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Laporan Import'),
              content: Text('Berhasil: $success siswa\nGagal / Invalid: $failed siswa'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))
              ],
            ),
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() {
          _isImporting = false;
          _importStatus = '';
        });
        ref.invalidate(daftarSiswaProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(daftarSiswaProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daftar Siswa Kelas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              _isImporting 
                ? Row(
                    children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text(_importStatus, style: const TextStyle(fontSize: 12)),
                    ],
                  )
                : ElevatedButton.icon(
                    onPressed: _importExcel,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import Excel'),
                  ),
            ],
          ),
        ),
        Expanded(
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Terjadi kesalahan: $err')),
            data: (siswaList) {
              if (siswaList.isEmpty) return const Center(child: Text('Belum ada siswa di kelas ini.'));
              return ListView.builder(
                itemCount: siswaList.length,
                itemBuilder: (context, index) {
                  final siswa = siswaList[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text(siswa.nama[0])),
                    title: Text(siswa.nama),
                    subtitle: Text('NISN: $ {siswa.nisn}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {}, // Edit siswa (manual)
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VerifikasiOrtuTab extends ConsumerWidget {
  const _VerifikasiOrtuTab();

  Future<void> _proses(BuildContext context, String id, String status) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('prosesVerifikasiOrtu').call({
        'verifikasiId': id,
        'status': status,
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Berhasil $status')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(verifikasiOrtuProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (list) {
        if (list.isEmpty) return const Center(child: Text('Tidak ada permintaan verifikasi.'));
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('Ortu dari: $ {item.namaSiswa}'),
                subtitle: Text('Pendaftar: $ {item.namaOrtu}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _proses(context, item.id, 'disetujui')),
                    IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _proses(context, item.id, 'ditolak')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _IzinSakitTab extends ConsumerWidget {
  const _IzinSakitTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(izinSakitProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (list) {
        if (list.isEmpty) return const Center(child: Text('Tidak ada pengajuan izin/sakit.'));
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            final dateStr = DateFormat('dd MMM yyyy').format(item.tanggal);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('$ {item.namaSiswa} - $ {item.keterangan}'),
                subtitle: Text('$dateStr\nAlasan: $ {item.alasan}'),
                isThreeLine: true,
                trailing: ElevatedButton(
                  onPressed: () {}, // Panggil fungsi prosesIzinSakit di Cloud Functions
                  child: const Text('Review'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
