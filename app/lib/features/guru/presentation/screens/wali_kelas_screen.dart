import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/wali_kelas_provider.dart';
import '../domain/wali_kelas_models.dart';

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

class _DaftarSiswaTab extends ConsumerWidget {
  const _DaftarSiswaTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(daftarSiswaProvider);

    return state.when(
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
                icon: const Icon(Icons.info_outline),
                onPressed: () {}, // Detail siswa
              ),
            );
          },
        );
      },
    );
  }
}

class _VerifikasiOrtuTab extends ConsumerWidget {
  const _VerifikasiOrtuTab();

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
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () {}, // Terima
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () {}, // Tolak
                    ),
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
                  onPressed: () {}, // Cek Bukti & Setujui
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
