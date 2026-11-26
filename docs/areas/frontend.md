# Frontend

## Convenciones

- Tema oscuro "Forja cálida" (`ForgeColors` en `lib/app/theme.dart`).
- Copy de UI en español neutro con tuteo y frases cortas.
- El color de un área nunca es la única señal: siempre acompaña al nombre del área.

## Estado actual por módulo

- **Navegación (`lib/app/router.dart`, `lib/app/theme.dart`):**
  - `ShellRoute` con `NavigationBar` inferior para alternar entre `Hoy` (`/`) y `Metas` (`/goals`), manteniendo los redirects de autenticación (`/splash`, `/login`) y compartiendo `parseForgeHexColor` y estilos de `NavigationBar` en `theme.dart`.
  - Ruta `/goals/:id` (`parentNavigatorKey` raíz, sin barra inferior) para abrir `GoalDetailScreen` al tocar una `GoalCard` o navegar por URL.
- **Áreas (`lib/features/areas`, `lib/features/home/presentation/home_screen.dart`):**
  - Dominio y repositorio offline-first (`Area`, `AreaRepository`, `DriftAreaRepository`): `watchAll`, `create`, `rename`, `changeColor` y `delete` (borrado lógico) con sello `updated_at` en UTC y registro en `sync_outbox`.
  - Paleta de 5 colores y áreas por defecto (`lib/features/areas/domain/area_defaults.dart`): Salud (`#E07A5F`), Carrera (`#D4A373`), Finanzas (`#81B29A`), Relaciones (`#D98C9B`) y Ocio (`#A88BD9`), posiciones 0–4.
  - Sembrado inicial (A3) en `SyncService`: se crean una sola vez mediante `AreaRepository` únicamente tras un pull exitoso que confirme 0 áreas locales y remotas (incluidas las borradas lógicamente).
  - Pantalla `Hoy` (`HomeScreen`): lista de áreas con indicador de color + nombre, creación rápida, menú contextual por área para renombrar, cambiar color (entre los 5 colores de área) y eliminar con diálogo de confirmación.
- **Metas (`lib/features/goals/presentation/`):**
  - `GoalRepository.watchAll()` / `DriftGoalRepository.watchAll()`, `goalsStreamProvider` y `goalActionsStreamProvider` para observar metas activas y las acciones de una meta ordenadas por `position`.
  - `GoalActionRepository.reorder(goalId, orderedIds)` / `DriftGoalActionRepository.reorder` para reescribir posiciones en una sola transacción, sellar `updated_at` y encolar en `sync_outbox` únicamente las acciones cuya posición cambió.
  - `GoalsScreen` (`Metas`): encabezado con el conteo de metas activas, chips de filtro por área (`Todas` + áreas activas), metas agrupadas por área según su posición, estado vacío con CTA, y `GoalCard` tocable con título, nombre y color de área, métrica sin decimales innecesarios, barra y porcentaje (acotado 0–100 %, `0%` si el objetivo es 0), horas semanales objetivo (`"6 h por semana"`, `"4 h 30 min por semana"`) y badge `"Meta cumplida"` en color positivo. Sin tiempo semanal real ni próxima acción (alcance S7).
  - `NewGoalScreen` (`Nueva meta` / `Editar meta`): formulario modal reutilizado para creación y edición (`goal != null`) con área (preseleccionada desde el filtro activo), título, "Por qué importa" opcional, fecha objetivo opcional con selector de fecha, avance actual (por defecto 0), objetivo numérico (> 0), unidad y horas semanales (≥ 0), validación inline en español y guardado mediante `GoalRepository.upsert` preservando `id` y `status`.
  - `GoalDetailScreen` (`Meta`): encabezado con área (color + nombre), estado (`Activa` / `Meta cumplida`), título, horas semanales objetivo, fecha objetivo opcional, acción `Editar` (reutilizando `NewGoalScreen`) y menú con `Marcar cumplida` / `Reactivar` y `Eliminar meta` (con confirmación y cascada A1); bloque de métrica con barra, porcentaje y diálogo `+ Registrar avance` (prefijado con el valor actual, valida `≥ 0`, sin historial per S5); sección `Por qué importa` oculta cuando está vacía; y plan de acción con `ReorderableListView` (agregar tarea o hito al final, marcar hecha/pendiente, reordenar por arrastre, eliminar por botón o deslizamiento con confirmación). Estado `Meta no encontrada` cuando el ID no existe o fue borrado. Fuera de alcance S7 oculto (anillo semanal, gráfico de 6 semanas, hábitos, horarios de acciones y `Planificar bloque`).

## Deuda técnica / pendientes

- Carga de metas reales y verificación de Fase 1 (T7) y prueba de sincronización en dispositivo real (L3).

