import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/medication/presentation/add_medication_screen.dart';
import '../../features/medication/presentation/medication_list_screen.dart';
import '../../features/tracking/presentation/today_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Pestañas principales con barra de navegación inferior.
    // Cada pestaña conserva su estado al cambiar entre ellas.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _HomeShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const TodayScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/medications',
              builder: (context, state) => const MedicationListScreen(),
            ),
          ],
        ),
      ],
    ),
    // Pantallas a pantalla completa (sin barra inferior)
    GoRoute(
      path: '/add-medication',
      builder: (context, state) => const AddMedicationScreen(),
    ),
  ],
);

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tocar la pestaña activa vuelve a su pantalla inicial
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Hoy',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'Medicamentos',
          ),
        ],
      ),
    );
  }
}
