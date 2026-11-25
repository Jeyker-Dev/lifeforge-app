# Frontend

## Convenciones

- Tema oscuro "Forja cálida" (`ForgeColors` en `lib/app/theme.dart`).
- Copy de UI en español neutro con tuteo y frases cortas.
- El color de un área nunca es la única señal: siempre acompaña al nombre del área.

## Estado actual por módulo

- **Navegación (`lib/app/router.dart`, `lib/app/theme.dart`):**
  - `ShellRoute` con `NavigationBar` inferior para alternar entre `Hoy` (`/`) y `Metas` (`/goals`), manteniendo los redirects de autenticación (`/splash`, `/login`) y compartiendo `parseForgeHexColor` y estilos de `NavigationBar` en `theme.dart`.
- **Áreas (`lib/features/areas`, `lib/features/home/presentation/home_screen.dart`):**
  - Dominio y repositorio offline-first (`Area`, `AreaRepository`, `DriftAreaRepository`): `watchAll`, `create`, `rename`, `changeColor` y `delete` (borrado lógico) con sello `updated_at` en UTC y registro en `sync_outbox`.
  - Paleta de 5 colores y áreas por defecto (`lib/features/areas/domain/area_defaults.dart`): Salud (`#E07A5F`), Carrera (`#D4A373`), Finanzas (`#81B29A`), Relaciones (`#D98C9B`) y Ocio (`#A88BD9`), posiciones 0–4.
  - Sembrado inicial (A3) en `SyncService`: se crean una sola vez mediante `AreaRepository` únicamente tras un pull exitoso que confirme 0 áreas locales y remotas (incluidas las borradas lógicamente).
  - Pantalla `Hoy` (`HomeScreen`): lista de áreas con indicador de color + nombre, creación rápida, menú contextual por área para renombrar, cambiar color (entre los 5 colores de área) y eliminar con diálogo de confirmación.
- **Metas (`lib/features/goals/presentation/`):**
  - `GoalRepository.watchAll()` / `DriftGoalRepository.watchAll()` y `goalsStreamProvider` para observar todas las metas activas (no borradas).
  - `GoalsScreen` (`Metas`): encabezado con el conteo de metas activas, chips de filtro por área (`Todas` + áreas activas), metas agrupadas por área según su posición, estado vacío con CTA, y `GoalCard` con título, nombre y color de área, métrica sin decimales innecesarios, barra y porcentaje (acotado 0–100 %, `0%` si el objetivo es 0), horas semanales objetivo (`"6 h por semana"`, `"4 h 30 min por semana"`) y badge `"Meta cumplida"` en color positivo. Sin tiempo semanal real ni próxima acción (alcance S7 / T6).
  - `NewGoalScreen` (`Nueva meta`): formulario modal con área (preseleccionada desde el filtro activo), título, "Por qué importa" opcional, fecha objetivo opcional con selector de fecha, avance actual (por defecto 0), objetivo numérico (> 0), unidad y horas semanales (≥ 0), con validación inline en español y guardado mediante `GoalRepository.upsert`.

## Deuda técnica / pendientes

- Detalle de meta y plan de acción (T6).

