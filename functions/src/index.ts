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
