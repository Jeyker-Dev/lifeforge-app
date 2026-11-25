# Frontend

## Convenciones

- Tema oscuro "Forja cálida" (`ForgeColors` en `lib/app/theme.dart`).
- Copy de UI en español neutro con tuteo y frases cortas.
- El color de un área nunca es la única señal: siempre acompaña al nombre del área.

## Estado actual por módulo

- **Áreas (`lib/features/areas`, `lib/features/home/presentation/home_screen.dart`):**
  - Dominio y repositorio offline-first (`Area`, `AreaRepository`, `DriftAreaRepository`): `watchAll`, `create`, `rename`, `changeColor` y `delete` (borrado lógico) con sello `updated_at` en UTC y registro en `sync_outbox`.
  - Paleta de 5 colores y áreas por defecto (`lib/features/areas/domain/area_defaults.dart`): Salud (`#E07A5F`), Carrera (`#D4A373`), Finanzas (`#81B29A`), Relaciones (`#D98C9B`) y Ocio (`#A88BD9`), posiciones 0–4.
  - Sembrado inicial (A3) en `SyncService`: se crean una sola vez mediante `AreaRepository` únicamente tras un pull exitoso que confirme 0 áreas locales y remotas (incluidas las borradas lógicamente).
  - Pantalla `Hoy` (`HomeScreen`): lista de áreas con indicador de color + nombre, creación rápida, menú contextual por área para renombrar, cambiar color (entre los 5 colores de área) y eliminar con diálogo de confirmación.

## Deuda técnica / pendientes

- Pantallas de metas y detalle de meta (T5/T6).

