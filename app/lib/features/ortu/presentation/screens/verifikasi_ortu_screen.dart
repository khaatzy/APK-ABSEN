import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class VerifikasiOrtuScreen extends ConsumerStatefulWidget {
  final VoidCallback onVerificationComplete;
  const VerifikasiOrtuScreen({super.key, required this.onVerificationComplete});

  @override
  ConsumerState<VerifikasiOrtuScreen> createState() => _VerifikasiOrtuScreenState();
}

class _VerifikasiOrtuScreenState extends ConsumerState<VerifikasiOrtuScreen> {
  final _nisnController = TextEditingController();
  String _hubungan = 'Ayah';
  File? _fotoKk;
  File? _fotoKartuPelajar;
  bool _isLoading = false;
  Map<String, dynamic>? _siswaData;

  Future<void> _cekSiswa() async {
    final nisn = _nisnController.text.trim();
    if (nisn.length != 10) return;
    
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('users')
          .where('role', '==', 'siswa')
          .where('nisn', '==', nisn)
          .limit(1)
          .get();
          
      if (snap.docs.isNotEmpty) {
        setState(() => _siswaData = snap.docs.first.data()..['id'] = snap.docs.first.id);
      } else {
        setState(() => _siswaData = null);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Siswa tidak ditemukan!')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(bool isKk) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        if (isKk) _fotoKk = File(pickedFile.path);
        else _fotoKartuPelajar = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitVerifikasi() async {
    if (_siswaData == null || _fotoKk == null || _fotoKartuPelajar == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Semua foto wajib diunggah!')));
      return;
    }

    final user = ref.read(authControllerProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final verifId = FirebaseFirestore.instance.collection('verifikasiOrtu').doc().id;
      final storageRef = FirebaseStorage.instance.ref('verifikasi/$ {user.uid}/$verifId');

      // Upload Foto
      await storageRef.child('kk.jpg').putFile(_fotoKk!);
      await storageRef.child('kartu_pelajar.jpg').putFile(_fotoKartuPelajar!);
      
      final kkUrl = await storageRef.child('kk.jpg').getDownloadURL();
      final kpUrl = await storageRef.child('kartu_pelajar.jpg').getDownloadURL();

      // Simpan Data
      await FirebaseFirestore.instance.collection('verifikasiOrtu').doc(verifId).set({
        'ortuId': user.uid,
        'namaOrtu': user.nama,
        'siswaId': _siswaData!['id'],
        'namaSiswa': _siswaData!['nama'],
        'kelasId': _siswaData!['kelasId'],
        'hubungan': _hubungan,
        'fotoKkUrl': kkUrl,
        'fotoKartuPelajarUrl': kpUrl,
        'status': 'menunggu',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengajuan berhasil dikirim ke Wali Kelas.')));
        widget.onVerificationComplete();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Anak')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Masukkan NISN Anak', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nisnController,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(onPressed: _isLoading ? null : _cekSiswa, child: const Text('Cari')),
              ],
            ),
            
            if (_siswaData != null) ...[
              const Divider(height: 40),
              Text('Ditemukan: $ {_siswaData!['nama']} (Kelas: $ {_siswaData!['kelasId']})', style: const TextStyle(fontSize: 18, color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              DropdownButtonFormField<String>(
                value: _hubungan,
                decoration: const InputDecoration(labelText: 'Hubungan dengan Anak', border: OutlineInputBorder()),
                items: ['Ayah', 'Ibu', 'Wali'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (val) => setState(() => _hubungan = val!),
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ImagePickerButton(title: 'Foto KK', file: _fotoKk, onTap: () => _pickImage(true)),
                  _ImagePickerButton(title: 'Kartu Pelajar', file: _fotoKartuPelajar, onTap: () => _pickImage(false)),
                ],
              ),
              const SizedBox(height: 32),
              
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _isLoading ? null : _submitVerifikasi,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Kirim Pengajuan Verifikasi', style: TextStyle(fontSize: 16)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class _ImagePickerButton extends StatelessWidget {
  final String title;
  final File? file;
  final VoidCallback onTap;

  const _ImagePickerButton({required this.title, this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120, height: 120,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
        child: file != null
            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(file!, fit: BoxFit.cover))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [const Icon(Icons.camera_alt, size: 40, color: Colors.blue), const SizedBox(height: 8), Text(title)],
              ),
      ),
    );
  }
}
