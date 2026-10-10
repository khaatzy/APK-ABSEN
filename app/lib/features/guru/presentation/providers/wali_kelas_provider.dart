import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/wali_kelas_models.dart';
import '../../auth/domain/app_user.dart';

// Sementara menggunakan data dummy karena Firebase backend belum diisi data.
// Nantinya ini akan mengambil dari wali_kelas_repository.dart
final daftarSiswaProvider = FutureProvider.autoDispose<List<AppUser>>((ref) async {
  await Future.delayed(const Duration(seconds: 1)); // Simulasi loading
  return [
    AppUser(uid: 's1', nama: 'Budi Santoso', role: AppRole.siswa, nisn: '0011223344', kelasId: '7A'),
    AppUser(uid: 's2', nama: 'Siti Aminah', role: AppRole.siswa, nisn: '0011223355', kelasId: '7A'),
  ];
});

final verifikasiOrtuProvider = FutureProvider.autoDispose<List<VerifikasiOrtu>>((ref) async {
  await Future.delayed(const Duration(seconds: 1));
  return [
    VerifikasiOrtu(
      id: 'v1', ortuId: 'o1', namaOrtu: 'Pak Santoso', namaSiswa: 'Budi Santoso',
      fotoKkUrl: 'https://dummy.url/kk', kartuPelajarUrl: 'https://dummy.url/kp', status: StatusVerifikasi.pending,
    ),
  ];
});

final izinSakitProvider = FutureProvider.autoDispose<List<IzinSakit>>((ref) async {
  await Future.delayed(const Duration(seconds: 1));
  return [
    IzinSakit(
      id: 'i1', siswaId: 's2', namaSiswa: 'Siti Aminah', keterangan: 'Sakit', alasan: 'Demam tinggi',
      fotoSuratUrl: 'https://dummy.url/surat', tanggal: DateTime.now(), status: StatusVerifikasi.pending,
    ),
  ];
});
