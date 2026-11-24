# ADR-002: Regla de conflictos de sincronización

## Contexto

La app escribe primero en Drift y sincroniza después con la API (ver [ADR-001](ADR-001-api-from-day-one.md)). Un mismo dato puede editarse sin conexión en el celular y, mientras tanto, en otro lado (otro dispositivo o, a futuro, un agente IA). Hace falta una regla determinista para decidir qué versión queda.

## Decisión

- **Datos editables** (áreas, metas, planes, hábitos): gana la última edición según `updated_at`. El cliente envía su `updated_at`; la API guarda el cambio solo si es más reciente que el que tiene y, si no, responde con la versión del servidor.
- **Registros de tiempo**: solo se agregan, nunca se sobrescriben. Cada registro tiene un UUID generado en el cliente; si llegan dos registros distintos, quedan los dos.
- **Borrados**: lógicos, con `deleted_at`. Un borrado es una edición más y sigue la misma regla, así que un borrado hecho sin conexión también se sincroniza.

## Consecuencias

- La regla es simple y, con un solo usuario, la pérdida de datos es casi imposible.
- Depende de que el reloj del dispositivo sea razonable; un reloj muy adelantado haría ganar ediciones viejas. Se acepta para un solo usuario.
- Nunca se descarta un registro de horas, que es el dato más valioso de la app.
- Toda entidad sincronizable necesita `id` (UUID del cliente), `updated_at` y `deleted_at`.
