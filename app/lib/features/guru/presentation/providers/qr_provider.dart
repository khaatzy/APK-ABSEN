import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// Provider yang nge-fetch (listen) ke Firestore qrHarian/{guruId}
final dailyQrProvider = StreamProvider.autoDispose<String?>((ref) {
  final user = ref.watch(authControllerProvider).value;

  if (user == null || user.uid.isEmpty || user.role.name != 'guru') {
    return Stream.value(null);
  }

  // Mengikuti diagram: G -> DB (Ambil token QR hari ini)
  return FirebaseFirestore.instance
      .collection('qrHarian')
      .doc(user.uid)
      .snapshots()
      .map((doc) {
    if (doc.exists && doc.data() != null) {
      // Ambil token yang sudah digenerate oleh Cloud Functions
      return doc.data()!['token'] as String?;
    }
    return null;
  });
});
