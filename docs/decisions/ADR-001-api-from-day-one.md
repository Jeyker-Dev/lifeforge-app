# ADR-001: Backend con API desde el MVP

## Contexto

LifeForge se usa principalmente desde el celular. Se evaluaron dos caminos: una app solo local (Drift, sin servidor) con la API en una fase posterior, o una API desde el inicio.

La opción solo local da un MVP más rápido y sin mantenimiento, pero ata los datos a un dispositivo, deja el respaldo como un proceso manual y no permite integraciones. Las necesidades que pesan para el dueño del producto son la seguridad y el respaldo de los datos y el uso de agentes IA sobre ellos, y todas requieren un servidor.

## Decisión

Construir desde el MVP un backend aparte, `lifeforge-api` (FastAPI + PostgreSQL), como fuente de verdad. La app Flutter mantiene Drift como caché offline con una cola de sincronización, para que registrar tiempo y ver el día funcione sin conexión.

## Consecuencias

- Los datos quedan respaldados en el servidor y abiertos a la web, a integraciones (FunWork, Finance) y a agentes IA vía MCP.
- El MVP tarda más: hay que construir auth, sincronización y deploy.
- La sincronización offline-first y la resolución de conflictos son la parte de mayor riesgo; se reutilizan los patrones ya probados en Finance (`ahorra-api`).
- Hay costo y mantenimiento del servidor, mitigados al compartir el VPS y el proxy Caddy existentes.
