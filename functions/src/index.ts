import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

// 1. Trigger saat Ortu mendaftar mandiri via Firebase Auth (Email/Password)
export const onOrtuRegistrasi = functions.auth.user().onCreate(async (user) => {
  // Set Custom Claims role = ortu
  await admin.auth().setCustomUserClaims(user.uid, { role: 'ortu' });
  
  // Simpan ke Firestore
  await admin.firestore().collection('users').doc(user.uid).set({
    role: 'ortu',
    email: user.email,
    nama: user.displayName || 'Orang Tua',
    anakIds: [],
    aktif: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
});

// 2. Callable Function: createUser (Moderator Only)
export const createUser = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'moderator') {
    throw new functions.https.HttpsError('permission-denied', 'Hanya moderator yang dapat membuat user.');
  }

  const { email, password, nama, role, nip } = data;

  const userRecord = await admin.auth().createUser({
    email,
    password,
    displayName: nama,
  });

  await admin.auth().setCustomUserClaims(userRecord.uid, { role });

  await admin.firestore().collection('users').doc(userRecord.uid).set({
    role,
    nama,
    email,
    nip: nip || null,
    aktif: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, uid: userRecord.uid };
});

// 3. Callable Function: createSiswa (Moderator atau Wali Kelas)
export const createSiswa = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Harus login.');

  const callerRole = context.auth.token.role;
  const callerWaliKelasDari = context.auth.token.waliKelasDari;
  const { nama, nisn, nis, nik, kelasId } = data;

  // Wali kelas hanya boleh buat siswa untuk kelasnya sendiri
  if (callerRole !== 'moderator') {
    if (callerRole !== 'guru' || callerWaliKelasDari !== kelasId) {
      throw new functions.https.HttpsError('permission-denied', 'Wali kelas hanya dapat membuat siswa di kelasnya sendiri.');
    }
  }

  const emailSintetis = `@siswa.smpn9probolinggo.local`;

  const userRecord = await admin.auth().createUser({
    email: emailSintetis,
    password: nik, // NIK sbg password
    displayName: nama,
  });

  await admin.auth().setCustomUserClaims(userRecord.uid, { role: 'siswa' });

  await admin.firestore().collection('users').doc(userRecord.uid).set({
    role: 'siswa',
    nama,
    nisn,
    nis,
    kelasId,
    aktif: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, uid: userRecord.uid };
});

// 4. Callable Function: setWaliKelas (Moderator Only)
export const setWaliKelas = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'moderator') {
    throw new functions.https.HttpsError('permission-denied', 'Hanya moderator yang berhak.');
  }

  const { kelasId, guruId } = data;

  // Cek jika kelas tsb sudah punya wali kelas, kita harus melepaskannya dulu
  const kelasDoc = await admin.firestore().collection('kelas').doc(kelasId).get();
  if (kelasDoc.exists) {
    const oldGuruId = kelasDoc.data()?.waliKelasId;
    if (oldGuruId && oldGuruId !== guruId) {
      await admin.auth().setCustomUserClaims(oldGuruId, { role: 'guru', waliKelasDari: null });
      await admin.firestore().collection('users').doc(oldGuruId).update({ waliKelasDari: null });
    }
  }

  // Set wali kelas baru
  await admin.auth().setCustomUserClaims(guruId, { role: 'guru', waliKelasDari: kelasId });
  await admin.firestore().collection('users').doc(guruId).update({ waliKelasDari: kelasId });
  await admin.firestore().collection('kelas').doc(kelasId).set({ waliKelasId: guruId }, { merge: true });

  return { success: true };
});

// 5. Scheduled Function: Generate Token QR Harian tiap jam 00:00 WIB
import { onSchedule } from 'firebase-functions/v2/scheduler';
import * as crypto from 'crypto';

export const generateDailyQR = onSchedule({
  schedule: 'every day 00:00',
  timeZone: 'Asia/Jakarta'
}, async (event) => {
  const db = admin.firestore();
  
  // Ambil semua user dengan role = guru
  const guruSnapshot = await db.collection('users').where('role', '==', 'guru').get();
  
  const batch = db.batch();
  const dateStr = new Date().toLocaleString('en-CA', { timeZone: 'Asia/Jakarta' }).split(',')[0]; // Format YYYY-MM-DD

  guruSnapshot.forEach((doc) => {
    const guruId = doc.id;
    // Generate random token yang sulit ditebak
    const token = crypto.randomBytes(16).toString('hex');
    
    const qrRef = db.collection('qrHarian').doc(guruId);
    batch.set(qrRef, {
      token: token,
      tanggal: dateStr,
      // Token harian berlaku sampai jam 23:59:59 di hari yang sama
      berlakuSampai: admin.firestore.Timestamp.fromDate(new Date($dateStrT23:59:59+07:00))
    });
  });

  await batch.commit();
  console.log(Berhasil membuat token QR harian untuk $ {guruSnapshot.size} guru.);
});

// 6. Reset QR (Dipanggil manual oleh guru jika QR bocor)
export const resetQr = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'guru') {
    throw new functions.https.HttpsError('permission-denied', 'Hanya guru yang dapat mereset QR.');
  }

  const guruId = context.auth.uid;
  const token = crypto.randomBytes(32).toString('hex');
  const dateStr = new Date().toLocaleString('en-CA', { timeZone: 'Asia/Jakarta' }).split(',')[0];

  await admin.firestore().collection('qrHarian').doc(guruId).set({
    token: token,
    tanggal: dateStr,
    berlakuSampai: admin.firestore.Timestamp.fromDate(new Date($dateStrT23:59:59+07:00))
  }, { merge: true });

  return { success: true };
});

// 7. Proses Verifikasi Ortu (Oleh Wali Kelas)
export const prosesVerifikasiOrtu = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Unauthenticated');
  
  const { verifikasiId, status, alasanPenolakan } = data; // status: 'disetujui' | 'ditolak'
  const callerRole = context.auth.token.role;
  const callerWaliKelasDari = context.auth.token.waliKelasDari;

  const db = admin.firestore();
  const verifDoc = await db.collection('verifikasiOrtu').doc(verifikasiId).get();
  
  if (!verifDoc.exists) throw new functions.https.HttpsError('not-found', 'Data tidak ditemukan');
  
  const verifData = verifDoc.data()!;
  
  // Validasi hak akses (Hanya Moderator atau Wali Kelas dari anak tersebut)
  if (callerRole !== 'moderator') {
    if (callerRole !== 'guru' || callerWaliKelasDari !== verifData.kelasId) {
      throw new functions.https.HttpsError('permission-denied', 'Hanya wali kelas atau moderator.');
    }
  }

  // Update status
  await verifDoc.ref.update({
    status: status,
    diprosesOleh: context.auth.uid,
    alasanPenolakan: alasanPenolakan || null
  });

  // Jika disetujui, update data ortu dengan id anak
  if (status === 'disetujui') {
    await db.collection('users').doc(verifData.ortuId).update({
      anakIds: admin.firestore.FieldValue.arrayUnion(verifData.siswaId)
    });
  }

  return { success: true };
});

// 8. Proses Izin / Sakit
export const prosesIzinSakit = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'Unauthenticated');
  
  const { izinId, status, catatan } = data; // status: 'disetujui' | 'ditolak'
  const callerRole = context.auth.token.role;
  const callerWaliKelasDari = context.auth.token.waliKelasDari;

  const db = admin.firestore();
  const izinDoc = await db.collection('pengajuanIzin').doc(izinId).get();
  
  if (!izinDoc.exists) throw new functions.https.HttpsError('not-found', 'Data tidak ditemukan');
  
  const izinData = izinDoc.data()!;
  
  if (callerRole !== 'moderator') {
    if (callerRole !== 'guru' || callerWaliKelasDari !== izinData.kelasId) {
      throw new functions.https.HttpsError('permission-denied', 'Hanya wali kelas atau moderator.');
    }
  }

  await izinDoc.ref.update({
    status: status,
    diprosesOleh: context.auth.uid,
    catatan: catatan || null
  });

  // Jika disetujui, tulis absen status izin/sakit untuk hari tsb (contoh simpel 1 hari dulu)
  if (status === 'disetujui') {
    // Logika tulis absen:
    const absensiRef = db.collection('absensi').doc($ {izinData.tanggalMulai}_$ {izinData.siswaId});
    await absensiRef.set({
      siswaId: izinData.siswaId,
      kelasId: izinData.kelasId,
      tanggal: izinData.tanggalMulai,
      status: izinData.jenis, // 'izin' | 'sakit'
      waktuScan: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
  }

  return { success: true };
});

// Helper: Haversine distance (meter)
function getDistanceFromLatLonInM(lat1: number, lon1: number, lat2: number, lon2: number) {
  const R = 6371000; // Radius bumi dalam meter
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

// 9. Submit Attendance (Dipanggil oleh Siswa)
export const submitAttendance = functions.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.role !== 'siswa') {
    throw new functions.https.HttpsError('permission-denied', 'Hanya siswa yang dapat melakukan absen.');
  }

  const { qrPayload, lat, lng, akurasi } = data; // qrPayload = string JSON dari QR
  const siswaId = context.auth.uid;
  const db = admin.firestore();

  // 1. Cek akurasi GPS
  if (akurasi > 100) {
    throw new functions.https.HttpsError('failed-precondition', 'Akurasi lokasi terlalu buruk. Cari sinyal GPS yang lebih baik.');
  }

  let parsedQr: any;
  try {
    parsedQr = JSON.parse(qrPayload);
  } catch (e) {
    throw new functions.https.HttpsError('invalid-argument', 'Format QR tidak valid.');
  }
  const guruId = parsedQr.g;
  const token = parsedQr.t;

  // 2. Waktu server saat ini (Asia/Jakarta)
  const now = new Date();
  const options = { timeZone: 'Asia/Jakarta', hour12: false };
  const dateStr = now.toLocaleString('en-CA', options).split(',')[0]; // YYYY-MM-DD
  const timeStr = now.toLocaleTimeString('en-GB', options); // HH:mm:ss

  // 3. Cek apakah ini hari sekolah & jam valid (dari pengaturan)
  const settingsDoc = await db.collection('pengaturan').doc('aplikasi').get();
  if (!settingsDoc.exists) throw new functions.https.HttpsError('internal', 'Pengaturan sistem tidak ditemukan.');
  const settings = settingsDoc.data()!;
  
  // (Asumsi hari libur dan jam batas disimpan di pengaturan. Contoh fallback default:)
  const batasTerlambat = settings.batasTerlambat || '07:00:00';
  const jamAlpha = settings.jamAlpha || '10:00:00';
  const radiusMeter = settings.radiusMeter || 100;
  const latSekolah = settings.lokasiSekolah?.lat || -7.750;
  const lngSekolah = settings.lokasiSekolah?.lng || 113.210;

  if (timeStr >= jamAlpha) {
    throw new functions.https.HttpsError('out-of-range', 'Anda sudah lewat jam batas. Absen ditolak.');
  }

  // 4. Validasi Jarak (Geofencing)
  const jarak = getDistanceFromLatLonInM(lat, lng, latSekolah, lngSekolah);
  if (jarak > radiusMeter) {
    throw new functions.https.HttpsError('out-of-range', Anda berada di luar area sekolah (jarak $ {Math.round(jarak)}m));
  }

  // 5. Validasi Token QR Guru
  const qrDoc = await db.collection('qrHarian').doc(guruId).get();
  if (!qrDoc.exists) throw new functions.https.HttpsError('not-found', 'QR Guru tidak ditemukan.');
  
  const qrData = qrDoc.data()!;
  if (qrData.tanggal !== dateStr || qrData.token !== token) {
    throw new functions.https.HttpsError('invalid-argument', 'QR tidak valid atau sudah kedaluwarsa.');
  }

  // 6. Cek Data Siswa
  const siswaDoc = await db.collection('users').doc(siswaId).get();
  const kelasId = siswaDoc.data()?.kelasId;

  // 7. Simpan Absen (Transaksi untuk mencegah duplikasi di hari yang sama)
  const absensiId = $ {dateStr}_$ {siswaId};
  const absensiRef = db.collection('absensi').doc(absensiId);

  const statusAbsen = timeStr <= batasTerlambat ? 'hadir' : 'terlambat';

  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(absensiRef);
    if (doc.exists) {
      throw new functions.https.HttpsError('already-exists', 'Anda sudah absen hari ini!');
    }
    transaction.set(absensiRef, {
      siswaId,
      kelasId,
      guruId,
      tanggal: dateStr,
      waktuScan: admin.firestore.FieldValue.serverTimestamp(),
      status: statusAbsen,
      lokasi: { lat, lng },
      akurasiMeter: akurasi
    });
  });

  // 8. Kirim Notifikasi ke Orang Tua (Jika ada)
  // (Akan dieksekusi asinkron agar respon absen cepat)
  const verifOrtuSnap = await db.collection('verifikasiOrtu')
    .where('siswaId', '==', siswaId)
    .where('status', '==', 'disetujui')
    .get();
  
  const parentIds = verifOrtuSnap.docs.map(d => d.data().ortuId);
  // (Logika FCM diletakkan di sini, menggunakan firebase-admin/messaging)
  
  return { 
    success: true, 
    status: statusAbsen, 
    waktu: timeStr 
  };
});
