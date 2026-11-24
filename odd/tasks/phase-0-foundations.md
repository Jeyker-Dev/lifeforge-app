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
| T1 | S1 | api | Adaptar la plantilla a LifeForge (AGENTS, docs, puerto 5433) y suite en verde | inline | hecha | api db4cfef |
| T2 | S1 | api, app | CI de lint y tests en ambos repos | inline | hecha (sin ejecutar en GitHub: no hay remoto) | api 6cf3669, app 6fee5ea |
| T3 | S5 | docs | Confirmar la regla de conflictos con el dueño | inline | hecha | app 01da319 |
| T4 | S2 | app | Base de la app: Riverpod, router, tema Forja, login contra la API | inline | pendiente | |
| T5 | S3, S5 | api | Recurso `areas` sincronizable (UUID del cliente, `updated_at`, push/pull) | inline | pendiente | |
| T6 | S3, S6 | app | Drift + cola de sincronización con `Area` de punta a punta | inline | pendiente | |
| T7 | S4 | api | Deploy en el VPS con Caddy y backups (requiere autorización remota) | inline | pendiente | |

## Log

- L1 (2026-11-23, pedido original): "ok empecemos entonces" — tras recomendar arrancar por la Fase 0 (auth, sincronización offline y deploy).
- L2: el puerto 5432 local lo usa `ahorra-api`; LifeForge usa 5433.
- L3 (T1): build roto por renombrar el paquete en `pyproject.toml`; se fijó `module-name = "app"`. Unitarios (40), ruff y mypy en verde. Sin correr: tests de integración, porque requieren `.env` y PostgreSQL y el agente no tiene permiso para leer ni crear archivos `.env*`. El cambio de puerto a 5433 queda para cuando exista el `.env`.
- L4 (T1): con el `.env` creado y PostgreSQL en el puerto 5432 (ahorra-api apagado), la suite completa pasa: 74 tests. `alembic upgrade head` falla porque `JWT_SECRET` está vacío en `.env`.
- L5 (T1): cerrada. Con `JWT_SECRET` en `.env`, `docker compose up -d --build --wait api` migra hasta `2e215cbe92c7 (head)` y `GET /health` responde `{"status":"ok"}`. Las migraciones corren dentro del contenedor (`DATABASE_URL` usa el host `db`). El puerto sigue en 5432; cambiar a 5433 solo si se levanta junto con ahorra-api. Siguiente: T2 (CI).
- L6 (T2): workflows `ci.yml` en ambos repos. Pasos verificados localmente: API (ruff format, ruff check, mypy, 74 tests) y app (dart format, flutter analyze, flutter test). No se ejecutaron en GitHub porque los repos no tienen remoto. Riesgo: item 5 (CI); la verificación local cubre los comandos, no el runner. Siguiente: T3 (regla de conflictos).
- L7 (2026-11-23, T3): el dueño aceptó la regla propuesta ("Sí, aceptar"): gana la última edición por `updated_at`, los registros de tiempo solo se agregan y los borrados son lógicos (`deleted_at`). Registrada en ADR-002. Siguiente: T4, que requiere confirmar A1 (registro público o alta por CLI).
