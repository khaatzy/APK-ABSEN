import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PengajuanIzinScreen extends StatefulWidget {
  final String anakId;
  const PengajuanIzinScreen({super.key, required this.anakId});

  @override
  State<PengajuanIzinScreen> createState() => _PengajuanIzinScreenState();
}

class _PengajuanIzinScreenState extends State<PengajuanIzinScreen> {
  File? _fotoSurat;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked != null) setState(() => _fotoSurat = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan Izin / Sakit')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Unggah Foto Surat Keterangan / Dokter', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickImage,
              child: Container(
                height: 200,
                color: Colors.grey.shade200,
                child: _fotoSurat != null
                    ? Image.file(_fotoSurat!, fit: BoxFit.cover)
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 50), Text('Ketuk untuk memotret')]),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _fotoSurat == null ? null : () {}, // Integrasi Cloud Function
              child: const Text('Kirim Pengajuan'),
            )
          ],
        ),
      ),
    );
  }
}
