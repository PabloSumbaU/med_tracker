# Especificación de Requisitos de Software: App de Gestión de Medicamentos

## 1. Introducción

### 1.1 Propósito del Documento
El propósito de este documento es definir y detallar los requisitos funcionales, no funcionales, de datos y reglas de negocio para la primera versión (MVP) de la aplicación móvil de gestión de medicamentos. Este documento servirá como guía principal para el equipo de desarrollo, diseño y control de calidad.

### 1.2 Propósito del Sistema
El sistema es una aplicación móvil diseñada para ayudar a las personas a gestionar, recordar y registrar la toma de sus medicamentos. Su objetivo principal es mejorar la adherencia al tratamiento médico mediante un sistema de notificaciones confiable, gamificación (rachas) y seguimiento visual del historial del paciente.

### 1.3 Alcance
El alcance de esta primera versión incluye la gestión local de medicamentos (CRUD), programación de horarios, sistema de recordatorios locales (basados en tiempo y ubicación), y el registro del cumplimiento del paciente. No incluye en esta fase la sincronización en la nube, ni la interacción con terceros (médicos o cuidadores).

---

## 2. Descripción General del Sistema

### 2.1 Perspectiva del Producto
La aplicación operará como un sistema independiente (standalone) en el dispositivo móvil del usuario. Todo el procesamiento y almacenamiento de datos se realizará localmente (offline-first) para garantizar que las notificaciones funcionen sin dependencia de una conexión a internet.

### 2.2 Perfil de Usuarios
*   **Usuario Principal (Paciente):** Persona que necesita llevar un control de sus medicamentos. Requiere una interfaz intuitiva, accesible y de fácil lectura.

### 2.3 Características Principales
1. Gestión de inventario de medicamentos (Registro, Consulta, Modificación, Eliminación).
2. Configuración granular de dosis y horarios, incluyendo una breve descripción del tratamiento.
3. Sistema robusto de recordatorios y notificaciones locales.
4. Registro de tomas individuales con captura exacta de fecha y hora.
5. Seguimiento de cumplimiento (Calendario, Rachas y Panel de Estadísticas/Historial).
6. Recordatorios contextuales (al salir de casa).

### 2.4 Restricciones Generales
*   La aplicación debe funcionar completamente sin conexión a internet.
*   Las notificaciones deben dispararse a tiempo incluso si la aplicación está cerrada (cerrada en segundo plano o *killed*).
*   Se requerirán permisos de ubicación en segundo plano para la funcionalidad de "salir de casa".

---

## 3. Requisitos de Datos

El sistema debe almacenar y gestionar las siguientes entidades principales de forma local:

*   **Medicamento / Tratamiento:**
    *   `ID` (UUID)
    *   `Nombre` (String)
    *   `Descripción_Tratamiento` (Text) - *Breve descripción del propósito o indicaciones especiales (ej. "Tomar con el estómago lleno", "Tratamiento para la alergia").*
    *   `Tipo` (Pastilla, Jarabe, Inyección, etc.)
    *   `Estado` (Activo/Inactivo)

*   **Esquema/Programa de Dosis:**
    *   `ID_Medicamento` (UUID, Foreign Key)
    *   `Dosis` (String/Float - ej. "1 pastilla", "5 ml")
    *   `Frecuencia` (Diaria, Días específicos, Intervalo de horas)
    *   `Horarios_Establecidos` (Lista de Horas)

*   **Registro de Toma (Log de Cumplimiento):**
    *   `ID_Toma` (UUID)
    *   `ID_Medicamento` (UUID)
    *   `Fecha_Programada` (Date)
    *   `Hora_Programada` (Time)
    *   `Fecha_Real_Toma` (Date, Nulo si no se tomó)
    *   `Hora_Real_Toma` (Time, Nulo si no se tomó)
    *   `Estado` (Pendiente, Realizada, Omitida)

---

## 4. Reglas de Negocio (BR - Business Rules)

*   **BR-01 (Cálculo de Racha):** La racha ("streak") aumenta en 1 día solo si *todas* las tomas programadas para ese día natural (00:00 - 23:59) son marcadas como "Realizadas".
*   **BR-02 (Pérdida de Racha):** Si al finalizar el día natural existe al menos una toma marcada como "Omitida" o que se quedó en estado "Pendiente", la racha actual vuelve a 0.
*   **BR-03 (Tolerancia de Tomas):** Un usuario puede registrar una toma de forma retroactiva para el día en curso, pero el sistema debe guardar la hora real en la que se confirmó en la app.
*   **BR-04 (Geovallado):** El recordatorio de "llevar medicamentos al salir de casa" solo debe dispararse si el usuario se aleja a más de un radio predefinido (ej. 150 metros) de la ubicación guardada como "Casa".

---

## 5. Casos de Uso Principales

*   **CU-01: Gestionar Medicamentos (CRUD).** El usuario puede añadir un nuevo medicamento junto con la descripción de su tratamiento, editar su nombre o dosis, ver la lista completa, y eliminar o archivar los que ya no toma.
*   **CU-02: Responder a Recordatorio de Toma.** El usuario recibe una notificación push. Desde la misma notificación o entrando a la app, puede seleccionar "Tomar" u "Omitir". El sistema registra automáticamente la fecha y hora exacta de la acción.
*   **CU-03: Visualizar Historial y Estadísticas.** El usuario accede a un panel de métricas donde puede revisar su historial de cumplimiento en gráficos (ej. porcentaje de tomas a tiempo en el mes), ver el calendario y consultar su racha actual.
*   **CU-04: Configurar Recordatorio de Salida.** El usuario establece la ubicación de su casa y activa la alerta de proximidad para recordar llevar sus medicinas.

---

## 6. Requisitos de Interfaz de Usuario (UI/UX)

*   **UI-01:** La pantalla de inicio debe mostrar claramente las tomas pendientes del día actual en orden cronológico, indicando la hora programada de cada una.
*   **UI-02:** El panel de "Historial de Cumplimiento" debe incluir estadísticas visuales (ej. gráficos circulares o de barras) que muestren el porcentaje de adherencia al tratamiento de forma mensual o semanal.
*   **UI-03:** Al ver el detalle de un medicamento, la interfaz debe mostrar claramente la "Descripción del Tratamiento" en la parte superior para fácil referencia.
*   **UI-04:** La racha actual (Streak) debe estar gamificada, mostrándose de forma destacada con íconos (ej. un fuego 🔥) para incentivar al usuario.

---

## 7. Requisitos de Notificaciones

*   **NOT-01:** Las notificaciones deben ser locales (Local Push Notifications) programadas por el sistema operativo.
*   **NOT-02:** Deben incluir acciones directas (Action Buttons) en la propia notificación: "Tomado" y "Posponer (Snooze)".
*   **NOT-03:** Las notificaciones deben emitir un sonido distintivo (si el teléfono no está en silencio) para diferenciarse de mensajes comunes.

---

## 8. Arquitectura y Restricciones Técnicas

*   **Almacenamiento Local:** Se debe utilizar una base de datos local robusta (ej. SQLite, Room, CoreData) para garantizar el funcionamiento offline.
*   **Gestión en Segundo Plano:** El framework elegido debe soportar la programación de tareas en segundo plano (WorkManager en Android, BackgroundTasks en iOS) para calcular rachas al final del día y reprogramar alarmas si el dispositivo se reinicia.
*   **Servicios de Ubicación:** Se utilizará Geofencing (Geovallado) nativo del sistema operativo para optimizar el consumo de batería en los recordatorios de "salir de casa".

---

## 9. Criterios de Aceptación (Ejemplos)

*   **CA-01 (Notificaciones con app cerrada):** *Dado que* el usuario programó un medicamento a las 14:00 y cerró la app forzosamente (swipe up), *cuando* sean las 14:00, *entonces* el dispositivo debe mostrar la notificación con sonido.
*   **CA-02 (Rachas):** *Dado que* la racha es de 5 días y el usuario tiene 2 medicamentos hoy, *cuando* marca solo 1 como tomado y el otro como omitido al final del día, *entonces* al día siguiente la racha debe mostrarse como 0.
*   **CA-03 (Geofence):** *Dado que* el usuario activó la alerta de salida, *cuando* el GPS detecta que cruzó el umbral de 150m desde su casa, *entonces* recibe una notificación de "No olvides tus medicinas".

---

## 10. Requisitos Futuros (Fuera de Alcance - V2)

Las siguientes funcionalidades están documentadas para tenerlas en el radar arquitectónico, pero no forman parte de la primera versión:
*   **Soporte Multiusuario:** Capacidad para que un cuidador gestione los medicamentos de un paciente (roles).
*   **Integración con WhatsApp:** Envío de alertas automatizadas a familiares o cuidadores si un paciente omite una toma crítica mediante APIs de mensajería.
*   **Sincronización en la Nube:** Respaldo de datos y sincronización entre múltiples dispositivos del mismo usuario.
*   **Lectura de recetas con OCR:** Escanear la caja del medicamento para auto-rellenar el nombre y la dosis.