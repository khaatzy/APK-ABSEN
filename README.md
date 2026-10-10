# APK Absen SMPN 9 Probolinggo

Aplikasi absen harian siswa berbasis Flutter & Firebase.

## Fitur Utama
- **Moderator**: Mengatur data guru/walikelas, jam masuk, radius sekolah.
- **Guru**: Menghasilkan QR Code harian. Walikelas memverifikasi registrasi orang tua.
- **Siswa**: Scan absen dengan validasi GPS & Kamera. Lihat riwayat absen.
- **Orang Tua**: Registrasi (KK & Kartu Pelajar), notifikasi absensi, kirim surat sakit/izin.

## Arsitektur
Aplikasi ini menggunakan **Riverpod** (State Management) dan **GoRouter** (Routing) dengan struktur *Feature-First*.
