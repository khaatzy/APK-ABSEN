import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/app_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
final messagingProvider = Provider<FirebaseMessaging>((ref) => FirebaseMessaging.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(messagingProvider),
  );
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  AuthRepository(this._auth, this._firestore, this._messaging);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<AppUser?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      // Pengecekan aktif: false (Sesuai Issue #3)
      if (data['aktif'] == false) {
        await logout();
        throw Exception('Akun Anda dinonaktifkan. Hubungi Moderator.');
      }
      
      // Simpan FCM Token
      try {
        final token = await _messaging.getToken();
        if (token != null) {
          await _firestore.collection('users').doc(uid).update({
            'fcmTokens': FieldValue.arrayUnion([token])
          });
        }
      } catch (e) {
        // Abaikan jika gagal ambil token di emulator
      }

      return AppUser.fromMap(data, doc.id);
    }
    return null;
  }

  Future<AppUser?> loginSiswa(String nisn, String nik) async {
    try {
      final email = "$nisn@siswa.smpn9probolinggo.local";
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: nik,
      );
      if (userCredential.user != null) return await getUserData(userCredential.user!.uid);
      return null;
    } catch (e) {
      throw Exception('Login gagal: Periksa kembali NISN dan NIK Anda.');
    }
  }

  Future<AppUser?> loginUmum(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) return await getUserData(userCredential.user!.uid);
      return null;
    } catch (e) {
      throw Exception('Login gagal: Email atau Password salah.');
    }
  }

  Future<void> logout() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final token = await _messaging.getToken();
        if (token != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'fcmTokens': FieldValue.arrayRemove([token])
          });
        }
      } catch (e) {}
    }
    await _auth.signOut();
  }
}
