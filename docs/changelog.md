# Changelog

## 2026-11-26

- Added `GoalActionRepository.reorder` / `DriftGoalActionRepository.reorder` (single transaction, stamps `updated_at`, enqueues outbox entries only for actions whose position changed) and `goalActionsStreamProvider`.
- Added `/goals/:id` route in `routerProvider`, made `GoalCard` tappable, extended `NewGoalScreen` to support edit mode (`goal != null`), and implemented `GoalDetailScreen` with metric progress dialog (`Registrar avance`), conditional `Por qué importa`, goal edit/complete/reactivate/delete flows, `Meta no encontrada` state, and action plan management (add task/milestone, toggle done, drag reorder, delete with confirmation) excluding out-of-scope S7 widgets (S3, S5, S7).

## 2026-11-25

- Drift schema v2 (`AppDatabase`): added `goals` and `goal_actions` tables with v1-to-v2 migration preserving existing `areas` and sync metadata.
- Added `Goal` and `GoalAction` domain models, repository ports, Drift repositories (`DriftGoalRepository` with A1 cascade soft-delete to actions, `DriftGoalActionRepository`), and API remotes (`GoalsRemote`, `GoalActionsRemote`).
- Extended `SyncService` to push and pull `areas`, `goals`, and `goal_actions` in order with single-flight locking, per-entity cursors, 4xx outbox cleanup, and last-edit-wins conflict resolution on pull.
- Added `changeColor` to `AreaRepository`/`DriftAreaRepository`, area palette and A3 default area seeding (`Salud`, `Carrera`, `Finanzas`, `Relaciones`, `Ocio`) in `SyncService` after an empty successful area pull, and area rename, color picker, and delete confirmation dialogs in `HomeScreen` (S1, A3).
- Added `watchAll()` to `GoalRepository`/`DriftGoalRepository` and `goalsStreamProvider`, bottom `NavigationBar` (`Hoy` and `Metas`) in `routerProvider`, `GoalsScreen` grouped by area with filter chips, `GoalCard`, empty state, and `NewGoalScreen` with inline Spanish validation (S2, S7).
