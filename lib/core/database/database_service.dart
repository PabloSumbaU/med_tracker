import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Este Provider de Riverpod nos permitirá acceder a la base de datos desde cualquier parte de la app
final databaseProvider = FutureProvider<Database>((ref) async {
  return DatabaseService.initDB();
});

class DatabaseService{
  static Future<Database> initDB() async{
    // Obtenemos la ruta segura en el teléfono para guardar el archivo .db
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'med_tracker.db');

    // Abrimos (o creamos) la base de datos
    return await openDatabase(
      path,
      version: 1,
      onCreate: createSchema,
      onConfigure: configure,
    );
  }

  // Activamos el soporte para Llaves Foráneas (Foreign Keys) en SQLite.
  // Público para poder reutilizarlo en los tests con una base en memoria.
  static Future<void> configure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // Este método solo se ejecuta la primera vez que se instala la app
  static Future<void> createSchema(Database db, int version) async {
    // Tabla de Medicamentos
    await db.execute('''
      CREATE TABLE medications(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        type TEXT NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    // Tabla de Esquemas de Dosis
    await db.execute('''
      CREATE TABLE dose_schedules(
        medicationId TEXT PRIMARY KEY,
        dose TEXT NOT NULL,
        frequency TEXT NOT NULL,
        scheduledTimes TEXT NOT NULL,
        FOREIGN KEY (medicationId) REFERENCES medications (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de Historial (Tracking Logs)
    await db.execute('''
      CREATE TABLE tracking_logs(
        logId TEXT PRIMARY KEY,
        medicationId TEXT NOT NULL,
        scheduledDate TEXT NOT NULL,
        scheduledTime TEXT NOT NULL,
        actualTakeDate TEXT,
        actualTakeTime TEXT,
        status TEXT NOT NULL,
        FOREIGN KEY (medicationId) REFERENCES medications (id) ON DELETE CASCADE
      )
    ''');
  }
}