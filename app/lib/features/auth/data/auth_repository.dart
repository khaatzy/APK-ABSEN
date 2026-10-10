import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/app_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  );
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<AppUser?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return AppUser.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Fungsi khusus login Siswa menggunakan NISN (sebagai username) dan NIK (sebagai password)
  Future<AppUser?> loginSiswa(String nisn, String nik) async {
    try {
      // Firebase Auth butuh format email. Kita sintesiskan dari NISN.
      final email = "$nisn@siswa.smpn9probolinggo.local";
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: nik, // NIK digunakan sebagai password
      );
      
      if (userCredential.user != null) {
        return await getUserData(userCredential.user!.uid);
      }
      return null;
    } catch (e) {
      throw Exception('Login gagal: Periksa kembali NISN dan NIK Anda.');
    }
  }

  // Fungsi login umum (untuk Guru, Ortu, Moderator yang menggunakan Email)
  Future<AppUser?> loginUmum(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        return await getUserData(userCredential.user!.uid);
      }
      return null;
    } catch (e) {
      throw Exception('Login gagal: Email atau Password salah.');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
