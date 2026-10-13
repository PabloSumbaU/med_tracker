import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/medication/presentation/medication_list_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MedicationListScreen(),
    ),
    GoRoute(
      path: '/add-medication',
      // Temporalmente mostramos una pantalla hasta construir el formulario
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Agregar Medicamento')),
        body: const Center(child: Text('Formulario en construcción...')),
      ),
    ),
  ],
);