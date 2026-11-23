# Diseño

## Design system

Vive en [stitch-design.md](stitch-design.md): es el archivo que se sube a Stitch como DESIGN.md, así que contiene solo el design system.

Dirección elegida: **Forja cálida**. Fondo carbón con acento ámbar como brasa, colores cálidos por área de vida y anillos de progreso para planificado vs. real. Se eligió frente a una dirección "calma minimalista" porque cuenta la metáfora del nombre, motiva sin gritar y se diferencia de Finance.

Inspiración: Structured (timeline del día), Apple Fitness (anillos), Sunsama y Things 3 (calma tipográfica), Griply (tarjetas de meta).

## Pantallas en Stitch

Proyecto "LifeForge" (id `7502043679311247552`), design system "Forja cálida" (`assets/a05859943ae349dfba5df215a9a66114`).

| Pantalla | Qué muestra | Fase |
|---|---|---|
| Hoy (`2a8f5ac265594769bc9e72c82d519277`, [captura](screens/hoy.png)) | Saludo y "Forjaste 2 h 15 min hoy", anillos por área con real/objetivo, timeline del día con bloque en curso ("Terminar"), margen protegido, bloque planificado ("Empezar"), FAB "Registrar tiempo" | Fase 2 |
| Metas (`f3b43747c62040e694d3e8eb59d876a4`, [captura](screens/metas.png)) | "4 metas activas · 9 h forjadas esta semana", chips por área, GoalCards agrupadas por área con métrica, barra, horas de la semana, próxima acción, badge "Meta cumplida" y aviso "Área descuidada", FAB "+ Nueva meta" | Fase 1 |

## Pendientes

- Hoy: se pidió en Stitch el espacio inferior para el FAB, el formato "1 h 30 min" en los anillos y las 5 áreas en grilla; la captura de `screens/hoy.png` es anterior a esa edición. Revisar que las etiquetas de los anillos no queden por debajo de 12px.
- Metas: la barra superior dice "Hoy" en lugar de "Metas"; los encabezados de sección usan "4h 30m" en vez de "4 h 30 min".
- Stitch derivó tokens M3 propios (por ejemplo, primary `#ffb68d`); en Flutter mandan los hex de `stitch-design.md`.
- Generar Detalle de meta y Revisión semanal.

- Generar Metas, Detalle de meta y Revisión semanal.
- Revisar en Stitch que los colores generados respeten los hex de `stitch-design.md`; en Flutter mandan los de ese archivo.
