enum MedicationType {
  pastilla('Pastilla'),
  jarabe('Jarabe'),
  inyeccion('Inyección'),
  gotas('Gotas'),
  inhalador('Inhalador'),
  otro('Otro');

  const MedicationType(this.label);

  /// Nombre para mostrar en la interfaz.
  final String label;
}

enum MedicationStatus {
  activo,
  inactivo
}

class Medication{
  final String id; //UUID
  final String name;
  final String? description;
  final MedicationType type;
  final MedicationStatus status;

  Medication({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    this.status = MedicationStatus.activo
  });

  Medication copyWith({
    String? id,
    String? name,
    String? description,
    MedicationType? type,
    MedicationStatus? status
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status
    );
  }

}