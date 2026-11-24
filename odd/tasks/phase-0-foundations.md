# Fase 0 — Cimientos

Objetivo: una app vacía que inicia sesión, guarda un dato offline y lo sincroniza con la API desplegada.
Ramas: `feat/phase-0` en `lifeforge` y en `lifeforge-api`. Entrega: `ask-on-risk`. Tests: `uv run pytest` (API) y `flutter test` (app).

## Specs

- S1. Roadmap, Fase 0: "Repos `lifeforge` (Flutter) y `lifeforge-api` (FastAPI + PostgreSQL) con CI de lint y tests."
- S2. Roadmap, Fase 0: "Auth: registro e inicio de sesión con JWT y refresh token rotativo."
- S3. Roadmap, Fase 0: "Base Drift, cola de sincronización y entidad de prueba sincronizada de punta a punta."
- S4. Roadmap, Fase 0: "Deploy de la API en el VPS detrás de Caddy, con backups de PostgreSQL."
- S5. Roadmap, Fase 0: "Confirmar la regla de conflictos de sincronización (ver `01-architecture.md`)."
- S6. Criterio de cierre: "se crea un registro sin conexión en el celular y aparece en la base del servidor al recuperar la red."

Supuestos (por confirmar):
- A1. Un solo usuario: el alta se hace por CLI (como en el starter kit), sin registro público. Contradice "registro" de S2; se pregunta antes de T4.
- A2. La entidad de prueba de S3 es `Area` (área de vida), que la Fase 1 necesita igual.

## Tasks

| ID | Specs | Repo | Tarea | Ruta | Estado | Commit |
|---|---|---|---|---|---|---|
| T1 | S1 | api | Adaptar la plantilla a LifeForge (AGENTS, docs, puerto 5433) y suite en verde | inline | pendiente | |
| T2 | S1 | api, app | CI de lint y tests en ambos repos | inline | pendiente | |
| T3 | S5 | docs | Confirmar la regla de conflictos con el dueño | inline | pendiente | |
| T4 | S2 | app | Base de la app: Riverpod, router, tema Forja, login contra la API | inline | pendiente | |
| T5 | S3, S5 | api | Recurso `areas` sincronizable (UUID del cliente, `updated_at`, push/pull) | inline | pendiente | |
| T6 | S3, S6 | app | Drift + cola de sincronización con `Area` de punta a punta | inline | pendiente | |
| T7 | S4 | api | Deploy en el VPS con Caddy y backups (requiere autorización remota) | inline | pendiente | |

## Log

- L1 (2026-11-23, pedido original): "ok empecemos entonces" — tras recomendar arrancar por la Fase 0 (auth, sincronización offline y deploy).
- L2: el puerto 5432 local lo usa `ahorra-api`; LifeForge usa 5433.
