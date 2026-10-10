enum StatusVerifikasi { pending, disetujui, ditolak }

class VerifikasiOrtu {
  final String id;
  final String ortuId;
  final String namaOrtu;
  final String namaSiswa;
  final String fotoKkUrl;
  final String kartuPelajarUrl;
  final StatusVerifikasi status;

  VerifikasiOrtu({
    required this.id,
    required this.ortuId,
    required this.namaOrtu,
    required this.namaSiswa,
    required this.fotoKkUrl,
    required this.kartuPelajarUrl,
    required this.status,
  });
}

class IzinSakit {
  final String id;
  final String siswaId;
  final String namaSiswa;
  final String keterangan; // 'Sakit' atau 'Izin'
  final String alasan;
  final String fotoSuratUrl;
  final DateTime tanggal;
  final StatusVerifikasi status;

  IzinSakit({
    required this.id,
    required this.siswaId,
    required this.namaSiswa,
    required this.keterangan,
    required this.alasan,
    required this.fotoSuratUrl,
    required this.tanggal,
    required this.status,
  });
}
