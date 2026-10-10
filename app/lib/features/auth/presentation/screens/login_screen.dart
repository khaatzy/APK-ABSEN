import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Tab Siswa
  final _nisnController = TextEditingController();
  final _nikController = TextEditingController();
  
  // Tab Umum
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _loginSiswa() async {
    final nisn = _nisnController.text.trim();
    final nik = _nikController.text.trim();

    // Validasi 10 digit NISN dan 16 digit NIK
    if (nisn.length != 10 || int.tryParse(nisn) == null) {
      _showError('NISN harus 10 digit angka!');
      return;
    }
    if (nik.length != 16 || int.tryParse(nik) == null) {
      _showError('NIK harus 16 digit angka!');
      return;
    }

    try {
      await ref.read(authControllerProvider.notifier).loginSiswa(nisn, nik);
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _loginUmum() async {
    final email = _emailController.text.trim();
    final pwd = _passwordController.text.trim();
    if (email.isEmpty || pwd.isEmpty) {
      _showError('Email dan password tidak boleh kosong');
      return;
    }
    // Panggil logika login umum (Email+Password) di authController
    // Note: Anda perlu menambah method loginUmum di AuthController juga.
  }

  void _showError(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.school, size: 80, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Portal Absensi\nSMPN 9 Probolinggo',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Siswa'),
                Tab(text: 'Guru / Ortu / Mod'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // TAB SISWA
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextField(
                          controller: _nisnController,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          decoration: const InputDecoration(labelText: 'NISN (10 Digit)', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nikController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          maxLength: 16,
                          decoration: const InputDecoration(labelText: 'NIK (16 Digit)', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: isLoading ? null : _loginSiswa,
                          child: isLoading ? const CircularProgressIndicator() : const Text('Masuk sebagai Siswa'),
                        ),
                      ],
                    ),
                  ),
                  // TAB UMUM
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: () {}, child: const Text('Lupa Password?')),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: isLoading ? null : _loginUmum,
                          child: isLoading ? const CircularProgressIndicator() : const Text('Masuk'),
                        ),
                        const SizedBox(height: 16),
                        TextButton(onPressed: () {}, child: const Text('Orang Tua? Daftar di sini')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
