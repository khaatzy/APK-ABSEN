import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/presentation/providers/auth_provider.dart';

// Menghasilkan payload QR yang aman dan unik per hari per guru
final dailyQrProvider = Provider.autoDispose<String?>((ref) {
  final authState = ref.watch(authControllerProvider);
  final user = authState.value;

  if (user == null || user.uid.isEmpty) return null;

  // Format: ABSEN_IDGURU_YYYYMMDD
  // Contoh: ABSEN_guru123_20261010
  final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
  final qrPayload = 'ABSEN__';
  
  return qrPayload;
});
