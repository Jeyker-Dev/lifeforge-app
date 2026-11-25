# Changelog

## 2026-11-25

- Drift schema v2 (`AppDatabase`): added `goals` and `goal_actions` tables with v1-to-v2 migration preserving existing `areas` and sync metadata.
- Added `Goal` and `GoalAction` domain models, repository ports, Drift repositories (`DriftGoalRepository` with A1 cascade soft-delete to actions, `DriftGoalActionRepository`), and API remotes (`GoalsRemote`, `GoalActionsRemote`).
- Extended `SyncService` to push and pull `areas`, `goals`, and `goal_actions` in order with single-flight locking, per-entity cursors, 4xx outbox cleanup, and last-edit-wins conflict resolution on pull.
- Added `changeColor` to `AreaRepository`/`DriftAreaRepository`, area palette and A3 default area seeding (`Salud`, `Carrera`, `Finanzas`, `Relaciones`, `Ocio`) in `SyncService` after an empty successful area pull, and area rename, color picker, and delete confirmation dialogs in `HomeScreen` (S1, A3).
- Added `watchAll()` to `GoalRepository`/`DriftGoalRepository` and `goalsStreamProvider`, bottom `NavigationBar` (`Hoy` and `Metas`) in `routerProvider`, `GoalsScreen` grouped by area with filter chips, `GoalCard`, empty state, and `NewGoalScreen` with inline Spanish validation (S2, S7).
