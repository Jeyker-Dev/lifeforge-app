# Roadmap

## Principios

- **Lo riesgoso primero**: auth, sincronización y deploy se resuelven en la Fase 0, antes de construir features encima.
- **Cada fase termina usable**: al cerrar una fase, la app se usa de verdad en el celular durante al menos una semana antes de seguir.
- **El núcleo antes que el pulido**: primero la cadena meta → plan → tiempo real; después hábitos, revisión e IA.
- **Unidades pequeñas y verificadas** (ODD): cada tarea con sus tests y su documentación.

## Fase 0 — Cimientos

Objetivo: una app vacía que inicia sesión, guarda un dato offline y lo sincroniza con la API desplegada.

- Repos `lifeforge` (Flutter) y `lifeforge-api` (FastAPI + PostgreSQL) con CI de lint y tests.
- Auth: inicio de sesión con JWT (alta del usuario por CLI) y refresh token rotativo.
- Base Drift, cola de sincronización y entidad de prueba sincronizada de punta a punta.
- Deploy de la API en el VPS detrás de Caddy, con backups de PostgreSQL.
- Confirmar la regla de conflictos de sincronización (ver `01-architecture.md`).

**Listo cuando**: se crea un registro sin conexión en el celular y aparece en la base del servidor al recuperar la red.

## Fase 1 — Metas

Objetivo: definir hacia dónde va mi vida.

- Áreas de vida (salud, carrera, finanzas, relaciones, ocio) editables.
- Metas por área, con métrica de avance y horas semanales objetivo.
- Plan de acción por meta: tareas puntuales e hitos.

**Listo cuando**: tengo cargadas mis metas reales (por ejemplo, conseguir trabajo) con su plan y sus horas objetivo.

## Fase 2 — Mi día

Objetivo: convertir las metas en horas reales. Es el corazón de LifeForge.

- Vista del día con time-blocking: bloques asociados a una meta o a tiempo protegido (descanso, sueño, margen).
- Registro de tiempo real con un toque (iniciar y terminar), funcionando offline.
- Notificaciones locales al inicio de cada bloque.
- Planificado vs. real por meta y por área en la semana.

**Listo cuando**: uso LifeForge todos los días una semana y veo cuántas horas reales le dediqué a cada meta.

## Fase 3 — Hábitos

- Hábitos recurrentes por meta, con frecuencia (por ejemplo, 3 veces por semana) y racha.
- Recordatorios locales de hábitos.
- Widget de pantalla de inicio para registrar tiempo o marcar hábitos.

## Fase 4 — Revisión semanal

- Ritual guiado: qué se cumplió, qué no y por qué.
- Resumen de la semana: horas por área, metas avanzadas y áreas descuidadas.
- Ajuste del plan de la semana siguiente.

## Fase 5 — IA e integraciones (opcional)

Opcional por ahora: se decide al cerrar la Fase 4, según el uso real. La API ya la deja posible sin cambios de arquitectura.

- Servidor MCP en la API para que un agente lea metas y proponga el plan del día.
- Integración con FunWork (proyectos como metas) y Finance (metas de ahorro).

## Referencias externas

- Patrones de sincronización y auth: `~/Work/finance` y `ahorra-api`.
- Infraestructura de deploy y proxy Caddy: `~/Work/funwork/docs/01-architecture.md`.
