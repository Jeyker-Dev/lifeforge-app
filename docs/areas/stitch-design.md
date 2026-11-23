# Design system — LifeForge (Forja cálida)

## Producto

App Android (Material 3, Flutter) de un solo usuario para administrar el tiempo diario en función de metas de vida.
Cadena central: área de vida → meta → plan → bloques en el día → horas reales.
Pregunta central de la app: "¿a qué le estoy dedicando mis horas y me acerca a la vida que quiero?"
Lema: "Forge the life you dream of, one hour at a time."
Fuera de alcance en la UI: login social, iOS, multiusuario, chat con IA.

## Tono

- Español neutro, tuteo, frases cortas.
- Motivador sin gritar: reconoce el esfuerzo ("Forjaste 3 h en Carrera hoy"), nunca culpa ("Te faltaron…" no, "Quedan 2 h para tu meta semanal" sí).
- Verbos concretos: "Empezar bloque", "Terminar", "Registrar tiempo", "Cerrar semana".

## Concepto visual

Metal al rojo sobre carbón: fondos oscuros y cálidos, un acento ámbar como brasa que se enciende cuando avanzás.
El progreso se representa con **anillos por área de vida** que se cierran con las horas reales frente a las planificadas.

## Color

Color mode: DARK (default). Primary color: #FF8A3D. Neutral (background): #14110F. Roundness: 16px.

### Dark mode palette (default)

| Token (equivalente M3) | Hex | Uso |
|---|---|---|
| primary (primary) | #FF8A3D | CTA, bloque en curso, foco, progreso |
| on-primary (on_primary) | #14110F | Texto e íconos sobre primary |
| background (background) | #14110F | Fondo |
| surface (surface_container) | #1E1A17 | Tarjetas, bloques del día |
| surface-high (surface_container_high) | #2A2420 | Hojas inferiores, elementos elevados |
| on-surface (on_surface) | #F2ECE6 | Texto principal |
| on-surface-muted (on_surface_variant) | #B3A79C | Etiquetas, horas secundarias |
| outline (outline_variant) | #3A322C | Solo divisores decorativos |
| outline-control (outline) | #8A7B6F | Bordes de inputs, checkboxes, bloques planificados (punteado) |
| area-health | #E07A5F | Salud |
| area-career | #D4A373 | Carrera |
| area-finance | #81B29A | Finanzas |
| area-relationships | #D98C9B | Relaciones |
| area-leisure | #A88BD9 | Ocio |
| protected-time | #8C9BAB | Descanso, sueño y margen |
| positive | #7BC47F | Meta o hábito cumplido |
| negative (error) | #F26B5B | Error |
| warning | #F2C94C | Área descuidada, bloque vencido |

### Light mode palette (reference)

| Token (equivalente M3) | Hex |
|---|---|
| primary (primary) | #B93C0A |
| on-primary (on_primary) | #FFFFFF |
| background (background) | #FAF6F1 |
| surface (surface_container) | #FFFFFF |
| surface-high (surface_container_high) | #F1EAE2 |
| on-surface (on_surface) | #1F1A16 |
| on-surface-muted (on_surface_variant) | #6B5E53 |
| outline (outline_variant) | #E2D8CD |
| outline-control (outline) | #857464 |
| area-health | #B4472C |
| area-career | #8A5A1F |
| area-finance | #2F6B4F |
| area-relationships | #A8445A |
| area-leisure | #6A4FA8 |
| protected-time | #55616E |
| positive | #276B2C |
| negative (error) | #B42318 |
| warning | #8A5A00 |

Contraste verificado (WCAG AA): todo texto y color de área ≥ 4,5:1 y outline-control ≥ 3:1 sobre background, surface y surface-high, en ambos modos. on-primary sobre primary: 8,0:1 (dark) y 5,7:1 (light).

- El color de área nunca es la única señal: siempre va con el nombre o el ícono del área.
- El ámbar (primary) se reserva para lo que está en curso o se acaba de lograr; no se usa como decoración.

## Tipografía

- Headline: Space Grotesk. Body: Inter. Label: Inter.
- Horas y porcentajes: Inter con cifras tabulares (tnum).

| Rol | Fuente | Tamaño | Line-height | Peso |
|---|---|---|---|---|
| display (horas del día, % del anillo) | Space Grotesk | 32px | 40px | 700 |
| headline | Space Grotesk | 24px | 32px | 700 |
| title | Space Grotesk | 20px | 28px | 600 |
| body | Inter | 16px | 24px | 400 |
| body-sm | Inter | 14px | 20px | 400 |
| label | Inter | 12px | 16px | 500 |

- Formato de tiempo: "2 h 30 min", "08:00–09:30", 24 h.

## Forma y espacio

- Radio: 16px en tarjetas y bloques, 999px en chips y botones de píldora.
- Espaciado base de 4px; márgenes laterales de 16px.
- Objetivos táctiles de al menos 48 dp.
- Sin sombras duras: la elevación se marca con surface-high y, en lo activo, un brillo ámbar suave.

## Componentes clave

| Componente | Descripción |
|---|---|
| AreaRing | Anillo por área de vida: arco lleno = horas reales, arco punteado = planificado. Centro con el % y el nombre del área. |
| DayTimeline | Timeline vertical del día con bloques coloreados por área; el bloque en curso brilla en ámbar; el tiempo protegido va en protected-time. |
| TimeBlock | Bloque con hora, meta, área y botón "Empezar" / "Terminar". Planificado sin registrar: borde punteado outline-control. |
| GoalCard | Meta con área, métrica de avance (por ejemplo, "3 de 10 entrevistas"), barra de progreso y horas de la semana (real / objetivo). |
| HabitChip | Hábito con frecuencia semanal y racha. |
| QuickTrack | Botón flotante para registrar tiempo con un toque. |

## Pantallas clave

1. **Hoy**: anillos de las áreas arriba, DayTimeline debajo, QuickTrack.
2. **Metas**: GoalCards agrupadas por área.
3. **Detalle de meta**: métrica, plan de acción, horas por semana.
4. **Revisión semanal**: anillos de la semana, logros, áreas descuidadas y ajuste del plan.
