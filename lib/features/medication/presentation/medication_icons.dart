import 'package:flutter/material.dart';
import '../domain/medication.dart';

extension MedicationTypeIcon on MedicationType {
  IconData get icon {
    switch (this) {
      case MedicationType.pastilla:
        return Icons.medication;
      case MedicationType.jarabe:
        return Icons.local_pharmacy;
      case MedicationType.inyeccion:
        return Icons.vaccines;
      case MedicationType.gotas:
        return Icons.water_drop;
      case MedicationType.inhalador:
        return Icons.air;
      case MedicationType.otro:
        return Icons.medical_services;
    }
  }
}
