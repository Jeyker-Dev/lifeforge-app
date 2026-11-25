# Fase 1 — Metas

Objetivo: cargar metas reales por área, con métrica de avance, horas semanales objetivo y plan de acción, sincronizadas offline como `Area`.
Ramas: `feat/phase-1` en `lifeforge` y en `lifeforge-api`. Entrega: `ask-on-risk`. Tests: `uv run pytest` (API) y `flutter test` (app). Implementación: en Antigravity, una tarea por vez, leyendo este documento hasta `## Log`.

## Specs

- S1. Roadmap, Fase 1: "Áreas de vida (salud, carrera, finanzas, relaciones, ocio) editables."
- S2. Roadmap, Fase 1: "Metas por área, con métrica de avance y horas semanales objetivo."
- S3. Roadmap, Fase 1: "Plan de acción por meta: tareas puntuales e hitos."
- S4. Criterio de cierre: "tengo cargadas mis metas reales (por ejemplo, conseguir trabajo) con su plan y sus horas objetivo."
- S5. Modelo aceptado por el dueño (L2):
  - **Meta (`Goal`):** área, título, "por qué importa" (opcional), fecha objetivo (opcional), métrica (valor actual, valor objetivo, unidad; por ejemplo "3 de 10 entrevistas"), horas semanales objetivo, estado (activa o cumplida).
  - **Acción del plan (`GoalAction`):** pertenece a una meta; título, tipo (tarea o hito), hecha o no, orden. Sin progreso parcial de hitos ("2 de 3") por ahora.
  - **"Registrar avance":** cambia el valor actual de la métrica; sin historial por ahora.
- S6. Sincronización igual que `Area` (ADR-002): UUID generado en el cliente, gana el `updated_at` más nuevo (empate conserva lo guardado), borrado lógico con `deleted_at`, pull por cursor `server_updated_at` que incluye borrados, aislamiento por usuario.
- S7. Pantallas de referencia: `docs/areas/screens/metas.png` y `docs/areas/screens/detalle-meta.png`. Fuera de alcance en esta fase (ocultar o dejar vacío): tiempo de la semana, gráfico de 6 semanas, hábitos y rachas, "Planificar bloque", horarios de acciones ("Hoy 14:00"), "Área descuidada".

Supuestos (por confirmar):
- A1. Borrar una meta borra lógicamente sus acciones en el cliente (cada acción viaja como su propio borrado); la API no hace cascada.
- A2. Una meta o acción cuya área o meta padre no existe para ese usuario se rechaza con 422.
- A3. Las áreas por defecto (salud, carrera, finanzas, relaciones, ocio) se crean desde la app la primera vez que no hay ninguna, no desde la API.

## Tasks

| ID | Specs | Repo | Tarea | Ruta | Estado | Commit |
|---|---|---|---|---|---|---|
| T1 | S2, S5, S6, A2 | api | Recurso `goals`: tabla, migración, `PUT /goals/{id}` y `GET /goals?since=`, con tests unitarios de la regla y de integración (auth, aislamiento, validación, área ajena) | Antigravity | pendiente | |
| T2 | S3, S5, S6, A2 | api | Recurso `goal_actions`: tabla, migración, `PUT /goal-actions/{id}` y `GET /goal-actions?since=`, mismos tests que T1 | Antigravity | pendiente | |
| T3 | S2, S3, S6, A1 | app | Drift: tablas `Goals` y `GoalActions`, repositorios con outbox y extensión de `SyncService` para empujar y traer metas y acciones (orden: áreas, metas, acciones), con tests | Antigravity | pendiente | |
| T4 | S1, A3 | app | Áreas editables: crear las 5 por defecto, renombrar, cambiar color y borrar desde la UI, con widget tests | Antigravity | pendiente | |
| T5 | S2, S7 | app | Pantalla Metas: lista agrupada por área, filtros por área, tarjeta con métrica y porcentaje, horas objetivo, "Nueva meta" con formulario, con widget tests | Antigravity | pendiente | |
| T6 | S3, S5, S7 | app | Detalle de meta: métrica con "Registrar avance", plan de acción (agregar, marcar hecha, reordenar, borrar), "Por qué importa", editar y marcar cumplida, con widget tests | Antigravity | pendiente | |
| T7 | S4 | api | Deploy de T1–T2 con `scripts/deploy.sh` y carga de las metas reales del dueño | inline | pendiente | |

## Log

- L1 (2026-11-25, pedido original): "Yes, start Phase 1".
- L2 (2026-11-25): el dueño aceptó el modelo propuesto: "sí, ese modelo me sirve, armá el plan, recuerda que cuando toque implementar lo haremos con antigravity". T1–T6 se implementan en Antigravity; este documento es la especificación que debe leer.
- L3: pendiente de Fase 0 que sigue abierto: la prueba de S6 de la Fase 0 en un dispositivo real.
