# Arquitectura

> Propuesta inicial. Las decisiones estructurales se registran en `decisions/`.

## Stack

- **App móvil**: Flutter (Android), en la raíz de este repo. Uso principal desde el celular.
- **Estado e inyección**: Riverpod.
- **Base local**: Drift (SQLite) como caché offline. Permite registrar tiempo y consultar el día sin conexión.
- **Notificaciones**: locales y programadas en el dispositivo para bloques y hábitos (no dependen del servidor).
- **Backend**: `lifeforge-api`, repositorio aparte en FastAPI con PostgreSQL. Es la **fuente de verdad** de los datos.
- **Sesión**: access token JWT de vida corta y refresh token rotativo, guardados en almacenamiento seguro del dispositivo.
- **Deploy de la API**: VPS propio con Docker, detrás del proxy Caddy compartido (red `edge`).
- **Agentes IA (fase posterior)**: servidor MCP en la API para que un agente lea metas y proponga el plan del día.

Ver [ADR-001](decisions/ADR-001-api-from-day-one.md).

## Capas y responsabilidades

### App (`lib/`, organizada por feature)

```
lib/
├── app/            Arranque, router, tema y ProviderScope
├── core/
│   ├── db/         Base Drift, tablas compartidas y migraciones
│   ├── sync/       Cola de sincronización hacia la API
│   ├── network/    Cliente HTTP, interceptor de tokens y refresh
│   ├── notifications/  Programación de notificaciones locales
│   └── ui/         Componentes visuales compartidos
└── features/
    └── <feature>/  auth, areas, goals, plan, habits, day, tracking, review
        ├── domain/        Dart puro: entidades, reglas y puertos
        ├── data/          DAOs de Drift, DTOs y adaptadores de la API
        └── presentation/  Pantallas, widgets y providers
```

### API (`lifeforge-api`)

| Capa | Responsabilidad |
|---|---|
| Routers | Endpoints HTTP por recurso, validación de entrada (Pydantic). |
| Servicios / casos de uso | Reglas de negocio: progreso de metas, planificado vs. real, revisión semanal. |
| Repositorios | Acceso a PostgreSQL. |
| Auth | Emisión y rotación de tokens; toda consulta filtra por usuario. |

## Flujo de datos

1. La app escribe primero en Drift y encola el cambio en `core/sync` (`sync_outbox`).
2. Con conexión, `SyncService` ejecuta un ciclo único a la vez (`_inFlight`) en orden: primero empuja el outbox pendiente (`areas` → `goals` → `goal_actions`) y luego descarga cambios por cursor individual en `sync_cursors` en el mismo orden (`areas` → `goals` → `goal_actions`).
3. La app actualiza Drift con la respuesta canónica del servidor; entradas inválidas (4xx/422) se descartan del outbox conservando la fila local.
4. Conflictos: gana la última edición según `updated_at` (un empate conserva la versión local); los registros de tiempo solo se agregan y nunca se sobrescriben; los borrados son lógicos (`deleted_at`). Borrar una meta en el cliente marca `deleted_at` también en sus acciones activas y encola un borrado por cada una. Ver [ADR-002](decisions/ADR-002-sync-conflict-rule.md).

### Tablas locales en Drift (`AppDatabase`)

| Tabla | Propósito |
|---|---|
| `areas` | Caché local de áreas de vida. |
| `goals` | Caché local de metas por área (métrica, horas semanales objetivo, estado). |
| `goal_actions` | Caché local de tareas e hitos ordenados por `position` dentro de cada meta. |
| `sync_outbox` | Cola de cambios locales pendientes de envío por entidad (`area`, `goal`, `goal_action`). |
| `sync_cursors` | Último `server_updated_at` recibido por entidad para pulls incrementales. |

## Convenciones críticas

- `domain/` es Dart puro: no importa Flutter, Drift ni HTTP.
- La UI nunca llama a la API directamente: lee de Drift mediante repositorios.
- Toda entidad sincronizable tiene un id generado en el cliente (UUID), `updated_at` y `deleted_at`.
- Las notificaciones se reprograman desde los datos locales, no desde el servidor.

## Mapa de rutas

Por definir junto con el roadmap.

## Decisiones

| ADR | Decisión |
|---|---|
| [ADR-001](decisions/ADR-001-api-from-day-one.md) | Backend con API desde el MVP, con la app móvil offline-first. |
| [ADR-002](decisions/ADR-002-sync-conflict-rule.md) | Gana la última edición; los registros de tiempo solo se agregan; borrados lógicos. |
