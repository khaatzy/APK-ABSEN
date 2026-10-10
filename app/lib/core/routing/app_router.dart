import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/guru/presentation/screens/guru_dashboard_screen.dart';
import '../../features/siswa/presentation/screens/siswa_dashboard_screen.dart';
import '../../features/ortu/presentation/screens/ortu_dashboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuth = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (authState.isLoading) return null;

      if (!isAuth) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        // Redirect based on role
        final role = authState.value!.role;
        switch (role) {
          case AppRole.siswa:
            return '/siswa';
          case AppRole.guru:
            return '/guru';
          case AppRole.ortu:
            return '/ortu';
          case AppRole.moderator:
            return '/moderator';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Dummy routes sementara untuk masing-masing role
      GoRoute(
        path: '/siswa',
        builder: (context, state) => const SiswaDashboardScreen(),
      ),
      GoRoute(
        path: '/guru',
        builder: (context, state) => const GuruDashboardScreen(),
      ),
      GoRoute(
        path: '/ortu',
        builder: (context, state) => const DummyScreen(title: 'Dashboard Orang Tua'),
      ),
      GoRoute(
        path: '/moderator',
        builder: (context, state) => const DummyScreen(title: 'Dashboard Moderator'),
      ),
    ],
  );
});

// Halaman sementara untuk memvalidasi routing
import 'package:flutter/material.dart';
class DummyScreen extends ConsumerWidget {
  final String title;
  const DummyScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ElevatedButton(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          child: const Text('Logout'),
        ),
      ),
    );
  }
}



