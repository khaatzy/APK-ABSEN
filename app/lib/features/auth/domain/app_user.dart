enum AppRole {
  moderator,
  guru,
  siswa,
  ortu,
}

class AppUser {
  final String uid;
  final String nama;
  final AppRole role;
  
  // Specific fields based on role
  final String? nisn; // for siswa
  final String? kelasId; // for siswa & guru (wali kelas)
  final List<String>? anakIds; // for ortu

  AppUser({
    required this.uid,
    required this.nama,
    required this.role,
    this.nisn,
    this.kelasId,
    this.anakIds,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String documentId) {
    return AppUser(
      uid: documentId,
      nama: map['nama'] ?? '',
      role: AppRole.values.firstWhere((e) => e.name == map['role'], orElse: () => AppRole.siswa),
      nisn: map['nisn'],
      kelasId: map['kelasId'],
      anakIds: map['anakIds'] != null ? List<String>.from(map['anakIds']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'role': role.name,
      'nisn': nisn,
      'kelasId': kelasId,
      'anakIds': anakIds,
    };
  }
}
