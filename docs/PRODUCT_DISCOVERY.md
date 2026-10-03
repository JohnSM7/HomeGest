# HomeGest — Product Discovery

> Estado: **borrador para revisión**. No hay código todavía. Fecha: 2026-10-03.
> Las cifras de precios, costes y plazos son **hipótesis a validar**, no hechos.

---

## 0. Resumen ejecutivo (leer esto primero)

**Veredicto crítico en cinco líneas**

1. La idea es buena, pero tal como está descrita son ~15 productos. Construirlos todos a la vez produce una app mediocre en todo. El producto tiene que ganar **una** batalla antes de ampliarse.
2. El hueco real no es "otra app de finanzas/tareas". Es **la coordinación de la vida compartida con captura casi sin esfuerzo**: *"lo digo o lo fotografío, y el sistema lo entiende y lo reparte"*.
3. **Cuña de entrada (wedge):** gasto compartido + lista de compra + tareas + calendario, todo con captura por IA y un único contexto de hogar. Documentos, vehículos, mascotas, mantenimiento, inventario y comidas son **extensiones del mismo motor**, no módulos independientes.
4. **Simplificación clave de arquitectura:** casi todo es "un registro con vínculos" (gasto ↔ vehículo ↔ documento ↔ tarea ↔ recordatorio). Vehículos, mascotas, vivienda y electrodomésticos son un único concepto genérico (**Asset**). Eso reduce el modelo de datos a la mitad y hace que el asistente sea mucho más potente.
5. **Lo que más riesgo tiene** no es la IA: es (a) el modelo de privacidad, (b) la integración bancaria (coste, regulación, mantenimiento) y (c) la retención (apps de hogar mueren porque *la otra persona no las usa*).

**Decisiones propuestas (resumen)**

| Tema | Propuesta |
|---|---|
| Unidad de producto | El **Hogar** (household). El "espacio personal" es un espacio de un solo miembro, mismo motor |
| Wedge | Gastos compartidos + compra + tareas + calendario + captura IA |
| Banca automática | **No en MVP 1.** Captura manual/voz/foto + (hipótesis) atajos de Apple Pay. Banca en MVP 2 como feature de pago |
| Privacidad | Cada registro tiene `visibilidad` + `grants`; se aplica en **la base de datos (RLS)**, no solo en el backend |
| IA | Capa de **acciones tipadas** (propose → confirm → execute), nunca SQL ni escrituras libres del LLM |
| Stack sugerido | TypeScript monorepo · Postgres (Supabase como host inicial) · Next.js (web/PWA) · Expo/React Native (móvil) |
| Gamificación | Casi nada. Solo "reparto justo de carga" visible, sin puntos ni rachas |
| Monetización | Freemium **por hogar** (no por usuario), premium = banca + IA ampliada + documentos/OCR |

---

## 1. Visión del producto

> **HomeGest es el sistema operativo del hogar: un único lugar donde las personas que comparten vida (pareja, familia, piso, cuidadores) coordinan dinero, compras, tareas, calendario y papeles — con una IA que convierte lo que dices, fotografías o recibes en acciones ya hechas.**

Principios rectores:

- **Captura sin fricción > organización perfecta.** Si registrar algo cuesta más de 5 segundos, no se hará.
- **La IA ejecuta, no decora.** Cada función de IA debe ahorrar pasos medibles.
- **Privado por defecto, compartir es un acto consciente.** Mínimo privilegio.
- **Un hogar no es una familia nuclear.** El modelo no asume estructura.
- **Aburrido y fiable antes que espectacular.** Dinero y papeles exigen confianza.
- **Menos pantallas, más "Hoy".** El producto se juzga por lo que *deja de hacer falta abrir*.

---

## 2. Propuesta de valor

**Para el usuario:**
- "Dejo de preguntar *¿quién paga qué?*, *¿falta algo en casa?*, *¿quién sacó la basura?*"
- "Apunto un gasto en 3 segundos hablando."
- "Todos los papeles de casa, coche y mascota se encuentran preguntando."
- "Sé cómo vamos de dinero sin hacer una hoja de cálculo."

**Para el hogar:**
- Una **fuente de verdad compartida** y visibilidad justa de la carga (dinero y trabajo doméstico).

**Diferenciación en una frase:** *Splitwise + Cozi + YNAB + Paperless, unidos por un asistente que actúa, con privacidad granular real.* Ninguna app existente cruza dinero y logística doméstica con permisos finos y captura por IA (ver §18).

**Las 3 promesas medibles** (sirven de norte para el MVP):
1. Registrar un gasto: **< 5 s** desde que abres la app.
2. Añadir a la compra: **< 3 s**, incluso por voz/atajo.
3. Responder "¿cuánto hemos gastado en X?" en **< 5 s** y con cifras correctas.

---

## 3. Usuarios objetivo

### Segmentos (prioridad de entrada)

| # | Segmento | Dolor principal | Prioridad |
|---|---|---|---|
| A | **Parejas (cohabitando)**, 25–45 | Gastos compartidos, compra, reparto de tareas | **Primario** |
| B | **Familias con hijos**, 30–50 | Logística: calendario, colegio, compra, tareas, papeles | **Primario** (segunda oleada) |
| C | **Compañeros de piso** | Reparto de gastos y suministros, limpieza | Secundario (adquisición viral, baja monetización) |
| D | **Persona sola** | Control personal + papeles + recordatorios | Secundario (entra gratis con el producto; poca razón de pago) |
| E | **Cuidadores / familias extendidas** (mayores a cargo) | Citas, medicación, documentos, coordinación | Futuro (alto valor, alta responsabilidad) |
| F | Pequeños equipos domésticos (servicio, etc.) | Tareas, turnos | No priorizar |

**Crítica:** empezar por **parejas** (A). Son el grupo con dolor financiero compartido más claro, onboarding de 2 personas (la invitación es el cuello de botella), y mayor disposición a pagar. Familias con hijos tienen más valor pero más complejidad (menores, roles, calendarios escolares).

### Personas de referencia

- **Marta (34) y Pablo (36)**, pareja, alquiler + coche, quieren dividir gastos sin discutir ni hojas de cálculo.
- **Familia García**: dos adultos, dos hijos (8 y 12), perro, hipoteca, dos coches. Caos de logística.
- **Lucía (27)** vive con 2 compañeros: suministros, limpieza, bote común.
- **Antonio (52)** cuida a su madre: citas médicas, recetas, facturas, coordinación con su hermana.

### Aviso sobre menores
Los hijos como usuarios (con cuenta) implican RGPD reforzado (en España, consentimiento de menores de 14 años por tutor). **MVP: los menores son "perfiles sin cuenta"** gestionados por adultos (miembros de tipo `dependent`). Cuenta propia para adolescentes: V2.

---

## 4. Casos de uso principales

| ID | Caso de uso | Frecuencia | Valor |
|---|---|---|---|
| U1 | Registrar un gasto (voz/texto/foto) y compartirlo | Diaria | ⭐⭐⭐ |
| U2 | Saber quién debe a quién y liquidar | Semanal/mensual | ⭐⭐⭐ |
| U3 | Añadir/consultar/marcar lista de compra (en el súper) | Diaria | ⭐⭐⭐ |
| U4 | Ver y completar "mis tareas / las del hogar" | Diaria | ⭐⭐⭐ |
| U5 | Ver "qué hay hoy" (agenda + tareas + avisos) | Diaria | ⭐⭐⭐ |
| U6 | Preguntar al asistente ("¿cuánto en restaurantes?") | Semanal | ⭐⭐ (⭐⭐⭐ si es exacto) |
| U7 | Guardar una factura/garantía y recuperarla después | Mensual | ⭐⭐⭐ (retención a largo plazo) |
| U8 | Recordatorio de vencimientos (ITV, seguro, garantía, revisión) | Mensual | ⭐⭐⭐ |
| U9 | Categorizar gastos pendientes (bandeja) | Semanal | ⭐⭐ |
| U10 | Ver presupuesto y objetivo de ahorro | Semanal | ⭐⭐ |
| U11 | Registrar una avería y seguir su resolución | Esporádica | ⭐⭐ |
| U12 | Planificar comidas → lista de compra | Semanal | ⭐ (nicho, alta complejidad) |

U1–U5 son el **núcleo diario**. U7/U8 son el **ancla de retención** (el hogar guarda sus papeles aquí; cambiar cuesta). Las dos juntas forman el producto.

---

## 5. Funcionalidades agrupadas por módulos (análisis y mejora de tu lista)

### Reestructuración propuesta

Tu lista tiene 20+ módulos. Propongo **5 pilares + 1 transversal + 1 motor**:

```
PILARES (lo que el usuario ve)
 1. Dinero      → gastos, ingresos, cuentas, presupuestos, suscripciones, deudas, objetivos de ahorro
 2. Compra      → listas, hábitos, (inventario/despensa después)
 3. Hacer       → tareas, recordatorios, recurrencias
 4. Agenda      → eventos, cumpleaños, vencimientos, tareas con fecha
 5. Casa y cosas→ ASSETS: vivienda, vehículos, mascotas, electrodomésticos
                  + documentos + mantenimiento + incidencias

TRANSVERSAL
 6. Asistente   → captura, consulta, acciones

MOTOR (invisible)
 7. Hogar y permisos · Automatizaciones · Notificaciones · Búsqueda · Auditoría
```

### Cambios respecto a tu planteamiento

| Tu propuesta | Mi recomendación | Por qué |
|---|---|---|
| Vehículos, Mascotas, Propiedad, Electrodomésticos como módulos separados | **Un solo concepto `Asset`** (tipo + atributos) con *pestañas comunes*: gastos, documentos, tareas, recordatorios, historial | Misma estructura de datos y UI; las diferencias son campos (matrícula/ITV vs. vacunas/chip). Reutilización máxima |
| Incidencias, Mantenimiento | Una sola cosa: **Tarea con contexto de Asset** (+ tipo `incidencia`, proveedor, presupuesto, garantía) | Evita otro módulo; una avería es una tarea con gasto y documentos vinculados |
| Facturas | No es módulo: es **Documento + Gasto/Obligación + Recordatorio** vinculados | La factura es un documento que genera un vencimiento y un gasto |
| Suscripciones | **Vista derivada** de gastos recurrentes detectados | No pedir al usuario que las cree; se detectan |
| Notas | **Nota = Documento ligero** o campo de otras entidades. Cuestionable como módulo | Notion/Apple Notes ya lo hacen mejor |
| "Mi actividad" | Es el **log de actividad** (auditoría visible), no un módulo | Reutiliza el sistema de auditoría |
| Comidas (recetas, menú, despensa) | **Fuera hasta V2/Futuro** | Complejidad enorme (recetas, nutrición, porciones); mercado saturado |
| Inventario | **Despensa ligera** (V2), generada desde compras, no inventario manual | El inventario manual muere en 2 semanas |
| Objetivos | Una entidad `Goal` con **métrica enlazada** (ahorro, gasto, tarea) | Si no se vincula a datos reales, es una nota |

### Detalle por pilar (con mejoras que no pediste)

**1. Dinero**
- Gasto con: importe, moneda, fecha, comercio, categoría, cuenta, pagador, **reparto** (quién participa y cuánto), visibilidad, adjuntos, origen (manual/voz/foto/banco), confianza.
- **Libro de saldos** entre miembros (quién debe a quién), con liquidaciones ("Pablo pagó 120 € a Marta").
- **Bandeja "por revisar"**: gastos con baja confianza o sin categoría. Es la pieza central del aprendizaje.
- **Memoria de comercio**: `MERCADONA → Supermercado` por hogar (y por usuario si difiere). Reglas explícitas > IA.
- Presupuestos por categoría y mes, con *alertas de ritmo* ("vas al 80% con el mes al 50%").
- Detección de **recurrentes/suscripciones** y **subidas de precio**.
- Ingresos: **privados por defecto, siempre**.
- Mejora: *"Modo pareja"* con reparto por defecto configurable (50/50, proporcional a ingresos, personalizado) **sin revelar los ingresos reales** (solo el porcentaje acordado).

**2. Compra**
- Listas múltiples (Semanal, Ferretería, Fiesta), productos con cantidad, nota, categoría de pasillo, quién lo añadió.
- **Tiempo real** entre miembros (es la función que más se nota).
- Modo "en la tienda": pantalla grande, tachado rápido, ordenado por sección.
- Aprendizaje (V2): frecuencia, sugerencias "¿ya se acabó el café?".
- Cierre de compra → opción de convertir el ticket en gasto (un tap).

**3. Hacer**
- Tarea: título, responsable(s), fecha, prioridad, recurrencia, subtareas, comentarios, adjuntos, vínculos a Assets.
- **Recurrencia flexible**: "cada 2 semanas" y "2 semanas *después de completarla*" (distinto; clave para tareas del hogar).
- **Rotación** de tareas ("sacar basura: turno semanal entre 3").
- **Carga visible**: quién ha hecho qué, sin ranking competitivo.
- Recordatorios = tareas con alerta y sin responsable ni estado complejo (no crear dos entidades; es un atributo `remind_at`).

**4. Agenda**
- Eventos con participantes, ubicación, recordatorios, visibilidad.
- **Importar/exportar ICS y sincronizar con Google/Apple/Outlook** (la gente no abandonará su calendario; hay que coexistir).
- Capa de **vencimientos** (facturas, ITV, garantías) y **cumpleaños** como vista, no eventos manuales.
- Conflictos y "¿quién puede recoger a los niños?" (V2).

**5. Casa y cosas (Assets + Documentos)**
- Asset: tipo (`property`, `vehicle`, `pet`, `appliance`, `person_dependent`, `other`), nombre, atributos tipados por plantilla.
- Plantillas con **calendario de mantenimiento por defecto** (ITV, revisión caldera, vacunas) → generan recordatorios.
- Documentos: subir/foto → OCR → extracción (emisor, fecha, importe, vencimiento, garantía) → **vincular a Asset** → buscable.
- Proveedores (fontanero, veterinario, taller) como contactos reutilizables.
- Incidencia = tarea con plantilla: estado, proveedor, presupuesto, factura, fecha reparación, garantía.

**6. Asistente** — ver §12.

---

## 6. Imprescindibles vs. secundarias

Criterio de decisión: **¿sin esto se valida o no la hipótesis central?** La hipótesis es: *"un hogar usará a diario una app compartida si registrar y consultar es casi instantáneo."*

| Funcionalidad | Veredicto | Motivo |
|---|---|---|
| Hogar + invitar miembros | 🔴 Imprescindible | Sin segundo usuario no hay producto |
| Privado / compartido (hogar) | 🔴 Imprescindible | Confianza desde el día 1 |
| Gasto manual + reparto + saldo | 🔴 Imprescindible | Dolor nº1 |
| Captura por texto/voz con IA | 🔴 Imprescindible | Es el diferenciador |
| Foto de ticket (extracción con LLM de visión) | 🔴 Imprescindible | Barata de hacer hoy, gran "wow" |
| Categorías + memoria de comercio | 🔴 Imprescindible | Habilita la IA útil |
| Lista de compra en tiempo real | 🔴 Imprescindible | Uso diario, adopción del 2º miembro |
| Tareas con responsable y recurrencia simple | 🔴 Imprescindible | Uso diario |
| Calendario interno + ICS | 🔴 Imprescindible | Contexto diario |
| Pantalla "Hoy" | 🔴 Imprescindible | Es la home |
| Notificaciones push | 🔴 Imprescindible | Retención |
| Asistente de consulta (solo lectura) + captura | 🔴 Imprescindible | Núcleo de IA |
| Documentos básicos (subir, vincular, buscar por título) | 🟠 MVP 2 | Ancla de retención, pero OCR añade complejidad |
| Banca automática (open banking) | 🟠 MVP 2 | Alto coste/riesgo; ver §15 |
| Vencimientos/garantías/recordatorios de Assets | 🟠 MVP 2 | Gran valor, requiere Assets+Docs |
| Presupuestos, objetivos de ahorro | 🟠 MVP 2 | Útil, no esencial para validar |
| Permisos a "miembros concretos" y grupos | 🟠 MVP 2 | Modelo lo soporta desde día 1; UI después |
| Detección de suscripciones | 🟡 V2 | Requiere histórico (banco) |
| Sync bidireccional calendarios | 🟡 V2 (ICS en MVP) | Complejidad y mantenimiento |
| Despensa/inventario ligero | 🟡 V2 | Depende de compras históricas |
| Automatizaciones configurables por el usuario | 🟡 V2 | Primero automatizaciones fijas "mágicas" |
| Correo (leer facturas) | 🟡 V2 | Privacidad y OAuth sensibles |
| Comidas/recetas | ⚪ Futuro | Mercado saturado, bajo encaje con el wedge |
| Gamificación | ⚪ Futuro/mínimo | Ver §9 |
| Pagos dentro de la app | ⚪ Futuro | Regulación (PSD2/licencias) |

---

## 7. Propuesta de MVP

### MVP 1 — "La pareja deja de discutir por dinero y compra" (8–12 semanas, equipo pequeño)

**Alcance (cerrado):**
1. Cuenta, hogar, invitación por enlace/código, perfiles de miembro.
2. Visibilidad: **Privado** / **Todo el hogar** (el modelo de datos ya soporta grants).
3. **Gastos**: crear manual, por texto/voz (IA) y por foto de ticket (IA); categorías; reparto y saldos; liquidaciones; bandeja "por revisar"; memoria de comercio.
4. **Compra**: listas compartidas en tiempo real; modo tienda; "cerrar compra → gasto".
5. **Tareas**: personales y de hogar, responsable, fecha, prioridad, recurrencia simple, subtareas, comentarios.
6. **Agenda**: eventos personales/hogar, cumpleaños, tareas con fecha, ICS import/export (suscripción de solo lectura).
7. **Hoy**: widgets fijos (no configurables todavía).
8. **Asistente**: captura (+Añadir en lenguaje natural) y consultas de lectura sobre gastos/tareas/compra/agenda; acciones con confirmación.
9. Push + recordatorios.
10. Exportar mis datos (RGPD) y borrar cuenta/hogar.
11. Auditoría interna y tests de aislamiento entre hogares.

**Fuera deliberadamente:** banca, documentos/OCR, assets, presupuestos, objetivos, automatizaciones, comidas, inventario, gamificación, grupos, roles avanzados.

**Éxito del MVP 1 (métricas de validación):**
- ≥ 60% de hogares invitados activan al 2º miembro en 7 días.
- ≥ 3 capturas/semana por hogar activo en la semana 4.
- Retención D30 de hogares ≥ 35% (hipótesis; calibrar con los primeros 50 hogares).
- ≥ 80% de gastos capturados por IA aceptados sin edición (tras la primera semana de aprendizaje).
- NPS cualitativo: ¿"volverías a una hoja de cálculo"? (esperado: no).

### MVP 2 — "El hogar guarda aquí sus papeles y el dinero entra solo"

- Documentos + OCR + extracción + búsqueda semántica.
- **Assets** (vivienda, vehículo, mascota, electrodoméstico) con plantillas de mantenimiento.
- Vencimientos, garantías, ITV, seguro → recordatorios automáticos.
- **Open banking** (premium) con confirmación de movimientos.
- Presupuestos y objetivos de ahorro.
- Permisos a miembros concretos; grupos.
- Widgets configurables en Hoy.
- Calendario: sync Google (lectura/escritura).

### V2

- Detección de suscripciones y cambios de precio.
- Automatizaciones personalizables (reglas "si → entonces").
- Despensa ligera y hábitos de compra (sugerencias).
- Correo (parseo de facturas con OAuth restringido).
- Incidencias con proveedores/presupuestos; rotaciones de tareas.
- Cuentas de adolescentes; modo cuidador.
- Compartir "solo totales" (nivel de detalle).
- Importación desde Splitwise/CSV bancarios.

### Futuro

- Comidas/recetas/menús; inventario completo; pagos y liquidaciones integradas; marketplace de proveedores; integraciones con domótica/electrodomésticos; modo cuidador clínico; API pública; gamificación ligera para niños.

---

## 8. Arquitectura de navegación

### Principios
- Móvil primero, **una mano**, acciones frecuentes en la zona del pulgar.
- 5 destinos máximo en la barra inferior; el resto en "Más".
- Cambiar de contexto (Personal ↔ Hogar X) es un gesto global, no una sección.

### Navegación móvil

```
┌──────────────────────────────────────────┐
│ ▾ Hogar García   🔍   🔔   (avatar)      │  ← selector de contexto
│                                          │
│            (contenido)                   │
│                                          │
│   ┌─────────────────────────────┐        │
│   │      ＋  Añadir  /  🎤      │ ← FAB  │
│   └─────────────────────────────┘        │
├──────────────────────────────────────────┤
│  Hoy │ Dinero │  ＋  │ Compra │ Más      │
└──────────────────────────────────────────┘
```

- **Barra inferior:** `Hoy · Dinero · [＋ Añadir] · Compra · Más`
  - **Tareas y Agenda** viven dentro de *Hoy* (vistas "Hoy / Semana") y en *Más*; si las pruebas muestran uso diario alto, Tareas sube a la barra y Compra a Hoy.
- **Selector de contexto** (arriba): `Todo (mío + hogares) · Personal · Hogar García · Piso Gracia`. Filtra todas las pantallas.
- **＋ Añadir** (hoja modal): línea de texto/voz grande arriba ("Escribe o di algo…") + atajos: Gasto · Tarea · Compra · Evento · Documento · Nota · Recordatorio.
- **Asistente**: accesible desde la misma barra de captura (el campo de texto es el asistente). Pantalla de chat completa desde *Más → Asistente* o deslizando.

### Mapa de pantallas

```
Hoy
 ├ Widgets (ver §11 dashboard)
 └ Actividad del hogar
Dinero
 ├ Resumen (mes, por categoría, presupuesto*)
 ├ Movimientos (lista + filtros)  ── Por revisar (badge)
 ├ Saldos / Liquidar
 ├ Cuentas y tarjetas
 └ Presupuestos* · Objetivos* · Suscripciones*
Compra
 ├ Listas
 └ Modo tienda
Más
 ├ Tareas (Mías · Hogar · Por persona)
 ├ Agenda (Día · Semana · Mes)
 ├ Casa y cosas*  (Assets)
 ├ Documentos*
 ├ Asistente
 ├ Actividad
 ├ Hogar (miembros, roles, invitaciones, ajustes)
 └ Perfil y configuración (privacidad, notificaciones, datos, plan)
(* = MVP 2)
```

### Web / escritorio
- Barra lateral izquierda fija con los mismos destinos + panel derecho opcional de asistente.
- Tablas densas para Movimientos, edición masiva y categorización por lotes (donde el escritorio gana al móvil).
- Atajo global `Cmd/Ctrl+K`: captura + búsqueda + comandos.

### Pantallas clave (bocetos)

**Dinero → Resumen**
```
Octubre · Hogar García            ▾
─────────────────────────────────────
Gastado   1.842 €   Presupuesto 2.400 €
▓▓▓▓▓▓▓▓▓▓▓░░░░░  77%  (día 18/31 ⚠ ritmo alto)
─────────────────────────────────────
Por categoría   [barras horizontales ordenadas]
 Supermercado 512 € · Vivienda 480 € · Ocio 210 € …
─────────────────────────────────────
⚠ 4 movimientos por revisar            →
Saldos: Pablo debe 38,20 € a Marta  [Liquidar]
─────────────────────────────────────
Movimientos recientes …
```

**Compra → Modo tienda:** lista a pantalla completa, filas altas (≥ 56 px), tachado con swipe/tap, secciones plegables, "+" persistente, indicación de quién añadió.

**Tareas:** pestañas `Mías · Hogar · Por persona`; fila = checkbox + título + responsable (avatar) + fecha relativa; swipe para posponer/completar; detalle en hoja inferior.

**Asistente:** chat con **tarjetas de acción** (no solo texto): "Voy a crear esta tarea: [Llevar coche al taller · Pablo · jueves] [Confirmar] [Editar] [Descartar]".

**Hogar:** miembros (rol, invitar), "qué compartimos" (matriz de privacidad legible), integraciones, exportación/eliminación.

---

## 9. Modelo de permisos (y privacidad)

Este es el corazón técnico y de confianza. Diseño propuesto:

### 9.1 Conceptos

- **Space (espacio):** contenedor de propiedad. Tipos: `personal` (1 miembro, uno por usuario) y `household` (N miembros). Todo registro pertenece a **exactamente un** Space.
- **Membership:** usuario ↔ hogar con `rol`.
- **Visibility** de cada registro (campo `visibility`):
  - `private` — solo el creador/propietario
  - `restricted` — creador + lista explícita de *grants*
  - `household` — todos los miembros del hogar dueño
- **Grant:** `(registro, sujeto, nivel)` donde sujeto = usuario o grupo; nivel = `view | comment | edit | manage`.
- **Grupo:** conjunto de miembros del hogar ("Padres", "Adultos", "Cuidadores"). V2/MVP 2.

> Un gasto personal en tu Space personal es privado. Un gasto de hogar puede ser visible a todos, a algunos o solo a quien lo pagó. **Los ingresos y cuentas bancarias son `private` por defecto y nunca heredan del hogar.**

### 9.2 Roles de hogar (plantillas, no estructura fija)

| Rol | Descripción | Puede |
|---|---|---|
| `owner` | Creador/es del hogar (puede haber varios) | Todo; eliminar hogar; gestionar roles |
| `admin` | Co-gestor | Invitar/expulsar, configurar, ver lo `household` |
| `member` | Adulto estándar | Crear y editar lo suyo; ver y colaborar en lo `household` |
| `limited` | Menor, invitado, cuidador | Solo lo que se le concede explícitamente |
| `dependent` | Perfil sin cuenta (hijo pequeño, mascota como persona de tareas) | Existe como asignable, sin acceso |

Roles son **plantillas de permisos por defecto**; un hogar puede personalizar. No se asume "padre/madre/hijo": el hogar nombra a sus miembros y roles (etiqueta libre `label`: "Madre", "Compañero Dani").

### 9.3 Matriz por defecto

| Dato | Visibilidad por defecto | Puede compartirse |
|---|---|---|
| Ingresos | `private` | A personas concretas, nunca a "todo el hogar" sin confirmación extra |
| Cuentas/tarjetas | `private` | Con miembros; opción "compartida" (cuenta conjunta) |
| Gastos | `household` si se crean en el hogar; `private` en Personal | Cualquiera |
| Documentos | `private` en Personal; `household` en hogar (con aviso para identidad/sanidad) | Cualquiera; categorías sensibles piden confirmación |
| Tareas | `household` en hogar; `private` en Personal | Cualquiera |
| Calendario | Eventos con visibilidad propia; modo **"ocupado/libre"** para ocultar detalle | Cualquiera |
| Compras | `household` | — |
| Notas | `private` | Cualquiera |
| Salud (mascotas ok; personas: sensible) | `private` | Con confirmación expresa |

### 9.4 Reglas de resolución (determinista)

```
puede_ver(usuario, registro) =
    registro.owner_user = usuario
 OR (registro.visibility = 'household' AND usuario es miembro activo de registro.space)
 OR (registro.visibility = 'restricted' AND existe grant(registro, usuario|grupo-del-usuario, nivel>=view))
 OR usuario es 'owner'/'admin' del hogar Y registro.admin_visible = true   -- ¡solo si el registro lo admite!
```

Decisiones importantes:

- **Admin NO ve lo privado.** Ni siquiera el `owner`. No hay "superusuario del hogar". (Ayuda ante el caso de relaciones de control.)
- **Los cambios de visibilidad se auditan** y notifican si reducen u otorgan acceso a otros.
- **Cuando alguien sale del hogar:** sus registros `private` se van con él; los `household` que creó se quedan (con atribución) o se exportan; los reparto/saldos se congelan y se muestran para liquidar.
- **Gastos compartidos con datos mixtos:** un gasto del hogar puede tener "mi parte" y "detalle" separados (cada participante ve su parte; el pagador y los participantes ven el total). El *saldo* es visible aunque el detalle personal no.
- **Nivel de detalle** (MVP 2/V2): compartir solo agregados ("gasto mensual en ocio") sin movimientos.

### 9.5 Cómo se impone (seguridad en profundidad)

1. **Row Level Security en Postgres** como barrera real (aunque el backend falle, la BD no devuelve filas ajenas).
2. Todas las tablas llevan `space_id` y `visibility`; políticas basadas en funciones `SECURITY DEFINER` pequeñas y testeadas (`is_member(space)`, `can_view(record)`).
3. **El asistente de IA ejecuta con los permisos del usuario que pregunta** (mismo `auth.uid()`), jamás con rol de servicio. Así no puede filtrar lo privado de otro miembro aunque el modelo "quiera".
4. Tests automáticos de aislamiento: suite que intenta cruzar hogares y miembros (ver §16).

---

## 10. Modelo de datos inicial

Convenciones: `id uuid`, `created_at/updated_at`, `deleted_at` (borrado lógico), dinero en **entero de unidades menores + moneda** (`amount_minor bigint`, `currency char(3)`), fechas con zona (`timestamptz`) y `date` donde aplique.

### 10.1 Diagrama conceptual

```
User ──< Membership >── Household(Space)
 │                         │
 └─ personal Space ────────┤   (todo registro pertenece a un Space)
                           │
   ┌───────────────────────┼─────────────────────────────────┐
 Account/Card         Transaction ──< Split        ShoppingList ──< ShoppingItem
   │                    │  │  └─ Category/Merchant       │
   └──── Transaction ───┘  └─ Document            Task ──< Subtask/Comment
                                                  Event ── Participants
 Asset ──< (links) >── Transaction | Document | Task | Event | Reminder
 Document ──< DocumentField (OCR/extracted)
 Goal ── métrica ──> Category | Account | Task set
 Budget ──< BudgetLine >── Category
 Automation ──< AutomationRun
 AuditLog · Notification · Invitation · Grant · Group
```

### 10.2 Entidades

**Identidad y hogar**
- `User` (id, email, nombre, locale, tz, avatar) — vinculado a Auth.
- `Space` (id, type `personal|household`, name, currency_default, tz, settings) — contenedor de propiedad.
- `Household` = Space `type=household` (+ `owner_ids`).
- `Membership` (space_id, user_id? | dependent_id?, role, label, status `invited|active|left`, joined_at).
- `Dependent` (perfil sin cuenta: nombre, fecha nacimiento, tipo `child|pet|elder`).
- `Invitation` (space_id, token hash, email?, role, expires_at, max_uses).
- `Group` y `GroupMember` (MVP 2).
- `Grant` (resource_type, resource_id, subject_type `user|group`, subject_id, level).

**Dinero**
- `Account` (space_id, owner_user_id, type `bank|card|cash|savings|loan`, name, last4, currency, visibility, institution_ref?, balance_minor?) — **sin credenciales**.
- `Transaction` (space_id, account_id?, payer_user_id, amount_minor, currency, occurred_on, merchant_id?, merchant_raw, category_id?, description, source `manual|voice|text|receipt|bank|import`, status `confirmed|pending_review|void`, confidence, visibility, recurring_id?, asset_id?, created_by, ai_meta jsonb).
- `TransactionSplit` (transaction_id, user_id, share_minor, settled boolean).
- `Settlement` (space_id, from_user, to_user, amount_minor, date, note).
- `Category` (space_id, parent_id, name, icon, kind `expense|income`, system boolean).
- `Merchant` (space_id, canonical_name, aliases[], default_category_id) — **memoria de aprendizaje** (regla explícita).
- `CategorizationRule` (space_id, matcher, category_id, origin `user|learned`, hits).
- `Budget` y `BudgetLine` (category_id, period, limit_minor).
- `RecurringPattern` / `Subscription` (merchant, importe típico, periodicidad, próxima fecha, estado, origen detectado/manual).
- `Income` (puede ser `Transaction` con `kind=income`, siempre `private` por defecto).
- `Goal` (space_id, owner/shared, name, target_minor, deadline, tracking `account|category|manual`, progress cache).
- `Obligation/Bill` (V2: factura con vencimiento, importe, estado pagada/pendiente).

**Compras**
- `ShoppingList` (space_id, name, store?, archived).
- `ShoppingItem` (list_id, name, qty, unit, product_id?, note, added_by, checked_by, checked_at).
- `Product` (space_id, name, aliases, default_category, typical_price?, typical_store?) — base para hábitos.
- `PurchaseEvent` (product_id, date, price?, store?) — histórico → frecuencia (V2).
- `InventoryItem` (V2): product_id, qty, location, expires_on, min_qty.

**Hacer y agenda**
- `Task` (space_id, title, notes, status, priority, due_at, remind_at, assignee_ids (tabla puente), recurrence jsonb (rrule + modo `fixed|after_completion`), parent_task_id, asset_id?, kind `task|incident|maintenance`, visibility, completed_by/at).
- `TaskComment`, `Attachment` (polimórfico).
- `Reminder` (si no se unifica con Task: subject polimórfico, remind_at, canal).
- `Event` (space_id, title, start/end/all_day, tz, location, rrule, visibility `…|busy_only`, source `internal|ics|google`, external_id).
- `EventParticipant` (event_id, user_id | dependent_id, rsvp).
- `CalendarConnection` (V2: tokens cifrados, sync cursor).

**Casa y cosas**
- `Asset` (space_id, type `property|vehicle|pet|appliance|other`, name, attributes jsonb validado por plantilla, purchase_date, owner_user_id?, visibility).
- `AssetTemplate` (tipo, campos, mantenimientos por defecto).
- `MaintenancePlan` (asset_id, name, interval, next_due, last_done → genera Tasks).
- `Provider` (space_id, name, category, contact, notes).
- `Warranty` (asset_id/document_id, starts_on, ends_on, provider).
- `Policy` (seguro: asset/space, aseguradora, nº póliza, vencimiento, prima) — o `Document` con campos extraídos.

**Documentos**
- `Document` (space_id, title, kind `invoice|contract|warranty|insurance|id|manual|receipt|other`, storage_key, mime, size, checksum, ocr_text, ocr_status, extracted jsonb, visibility, sensitivity).
- `DocumentLink` (document_id, entity_type, entity_id).
- `DocumentChunk` (document_id, text, embedding vector) — búsqueda semántica.

**Transversales**
- `EntityLink` (from_type, from_id, to_type, to_id, relation) — grafo ligero de vínculos (gasto↔activo↔documento↔tarea).
- `Tag` (opcional).
- `Notification` y `PushDevice`.
- `Automation` (space_id, trigger, conditions, actions, enabled, origin `system|user`) y `AutomationRun` (logs).
- `AssistantThread`, `AssistantMessage`, `AssistantAction` (propuesta, parámetros, estado `proposed|confirmed|executed|rejected|failed`, undo_data).
- `AuditLog` (space_id, actor, action, entity, before/after hash, ip, ts) — **append-only**.
- `Activity` (feed visible = proyección filtrada del audit por visibilidad).
- `Entitlement/Plan` (space_id, plan, límites, billing_ref).
- `Recipe`, `MealPlan`, `MealPlanEntry` (Futuro).

### 10.3 Relaciones clave

- Un **User** tiene exactamente un Space personal y 0..N memberships en hogares.
- Todo registro tiene `space_id` + `created_by` + `visibility` → política única, repetible.
- **Transaction ↔ Split** modela el reparto; los saldos se calculan como vista (`net_balance(user_a, user_b)`), nunca se guardan sin recalcular (o con tabla materializada verificada).
- **Asset** es el "ancla" de coste y papeleo: `SUM(Transaction WHERE asset_id)` responde "¿cuánto hemos gastado en mantener el coche?".
- **EntityLink** evita tablas puente por cada combinación.

---

## 11. Pantalla "Hoy" y sistema de widgets

### Jerarquía de información (de más a menos prioritaria)

1. **Lo que requiere acción hoy** (bloque único, ordenado por urgencia):
   tareas que vencen hoy · facturas/vencimientos próximos · gastos por revisar (si > 0) · lo que alguien te ha asignado.
2. **Agenda de hoy y mañana** (próximos eventos del contexto activo).
3. **Compra pendiente** (nº de productos + acceso a modo tienda).
4. **Dinero de un vistazo** (gastado este mes vs. ritmo; saldo con otros miembros).
5. **Sugerencias del asistente** (máx. 1–2: "El seguro del coche vence en 12 días").
6. **Actividad reciente del hogar** (colapsada).
7. Objetivos y mantenimiento (solo si hay algo relevante).

### Reglas anti-sobrecarga

- **Widgets vacíos no se muestran.** Nada de "0 tareas" ocupando espacio.
- Máximo ~5 tarjetas visibles sin scroll en móvil.
- **Un widget = una pregunta** ("¿qué debo hacer hoy?"), una acción primaria.
- Estado normal = pantalla corta; el producto "se calla" si no hay nada.
- Saludo y estado del hogar en una línea ("Hoy: 2 tareas, 1 evento, compra: 7 productos").

### Sistema de widgets

- Cada widget: `{ id, título, fuente de datos, tamaños (S/M/L), condición de visibilidad, acción primaria, permisos requeridos }`.
- **MVP 1:** conjunto fijo y ordenado automáticamente por urgencia (sin configuración).
- **MVP 2:** activar/desactivar, reordenar, tamaño; perfiles por contexto (Personal vs. Hogar).
- Los widgets consumen **queries tipadas** que respetan permisos; el mismo contrato lo usa el asistente (misma capa de lectura).
- Widgets del hogar muestran *a quién pertenece* cada cosa con avatares; los datos privados nunca aparecen en el widget de otro miembro.

---

## 12. Sistema de IA

### 12.1 Principio de diseño

> El LLM **no es la fuente de verdad ni tiene acceso directo a datos o escritura**. Es un *planificador/traductor* que llama a **herramientas tipadas** con permisos del usuario. Todo lo cuantitativo sale de consultas SQL deterministas, no del texto generado.

### 12.2 Capacidades

1. **Interpretación de captura** (texto/voz/foto → acción estructurada).
2. **Consulta** (preguntas sobre datos del hogar).
3. **Acciones** (proponer y ejecutar con confirmación).
4. **Categorización** (reglas → similitud → LLM).
5. **Extracción de documentos/tickets** (visión/OCR → campos).
6. **Proactividad** (resúmenes, avisos, sugerencias) — con moderación.

### 12.3 Arquitectura

```
Entrada (texto | voz→STT | foto→visión)
        │
   [Router de intención]  ← modelo pequeño/barato, salida JSON validada con esquema
        │
   ┌────┴─────────────┬──────────────────┐
 Captura        Consulta (RAG tipado)   Conversación
   │                  │                   │
 Propuesta        Tools de lectura     Respuesta + tarjetas
 (AssistantAction)   (query_expenses,        │
   │              list_tasks, …)             │
 Confirmación  ──── según política ──────────┘
   │
 Ejecutor (servicio de dominio, con permisos del usuario) → auditoría → undo
```

### 12.4 Herramientas (catálogo inicial)

Lectura: `query_transactions(filters, groupBy, period)`, `list_tasks`, `list_events`, `get_shopping_list`, `search_documents` (MVP 2), `get_balances`, `get_budget_status` (MVP 2).
Escritura (siempre vía propuesta): `create_transaction`, `categorize_transaction`, `add_shopping_items`, `create_task`, `create_event`, `create_reminder`, `link_document` (MVP 2), `create_incident` (MVP 2), `update_*`.

- Esquemas estrictos (JSON Schema/Zod) y validación server-side; el modelo propone, el servidor valida.
- **Resolución de entidades**: "Mercadona", "Pablo", "el coche" → IDs reales mediante búsqueda/fuzzy match, con desambiguación ("¿Te refieres al Seat o al Ford?").

### 12.5 Política de confirmación (tres niveles)

| Nivel | Ejemplos | Comportamiento |
|---|---|---|
| **A. Auto** (reversible, bajo riesgo, alta confianza) | Añadir producto a compra, categorizar con regla aprendida, crear recordatorio propio | Ejecuta y muestra "Hecho · Deshacer" (10 s+) |
| **B. Confirmar** | Crear gasto nuevo, tarea para otra persona, evento con invitados, mover dinero entre saldos | Tarjeta con valores editables: Confirmar/Editar |
| **C. Doble confirmación / manual** | Borrados masivos, cambiar visibilidad a más personas, enviar mensajes externos, liquidaciones | Confirmación explícita con resumen del impacto; no ejecutable por automatización |

Umbrales de confianza configurables por hogar (empezar conservador: pocas cosas en A).

### 12.6 Aprendizaje (sin "entrenar" modelos)

- Cada corrección del usuario crea/ajusta una **regla explícita** (`Merchant → Category`, alias de producto, preferencias de reparto).
- Orden de resolución: **regla del usuario > regla del hogar > histórico similar (embeddings) > LLM > preguntar**.
- Todo es auditable y editable en "Reglas aprendidas" (transparencia, evita "magia opaca").
- Ejemplo: "He detectado 43,20 € en MERCADONA. ¿Qué tipo de gasto es?" → respuesta "supermercado" → regla `MERCADONA → Supermercado` (hogar) + pregunta única "¿Aplicar siempre?".

### 12.7 Seguridad de IA (crítico)

- **Prompt injection**: el texto de documentos/correos/OCR/ticket se trata como **datos no confiables**, nunca como instrucciones; sin herramientas de escritura expuestas mientras se procesa contenido externo sin confirmación.
- Permisos: ejecución con identidad del usuario (RLS). Un miembro no puede obtener datos de otro por prompt.
- **Mínimo contexto**: se envía al proveedor solo lo necesario (nunca volcados de BD); redacción de PII innecesaria (IBAN, DNI) antes de enviar.
- Proveedor de IA con contrato **sin entrenamiento con nuestros datos**, región UE si es posible, y abstracción para poder cambiar de modelo.
- **Evaluaciones continuas** (golden set en español: "35 € de gasolina", "ayer cené con Marta 62"), con métricas de precisión de categorización/intent y regresiones por cambio de modelo/prompt.
- Control de coste: modelo pequeño para enrutado/categorización, modelo grande solo en conversación compleja y visión; caché por comercio; límites por plan.
- **No hay "dinero por IA"**: no ejecutar pagos ni transferencias.

### 12.8 Qué NO hará la IA al principio
Asesoramiento financiero/fiscal, diagnóstico veterinario/médico, redacción de mensajes a terceros, acciones sin traza, consultas con SQL libre.

---

## 13. Sistema de automatizaciones

### 13.1 Enfoque

Dos capas:
1. **Automatizaciones de sistema** (siempre activas, probadas, "mágicas"): MVP 1/2.
2. **Reglas de usuario** (`si… cuando… entonces…`): V2. No construir un motor genérico antes de saber qué se usa.

### 13.2 Modelo

```
Automation = Trigger (evento de dominio | programación | umbral)
           + Conditions (sobre datos y permisos)
           + Actions (pasos tipados, con política de confirmación A/B/C)
           + Guardrails (límite de frecuencia, idempotencia, modo "solo sugerir")
```

- Basado en **eventos de dominio** (`transaction.created`, `document.processed`…) en un outbox transaccional → cola → workers idempotentes.
- Cada ejecución en `AutomationRun` con motivo, entrada, salida, y *por qué* (explicabilidad).
- Modo **"sugerir en vez de ejecutar"** para automatizaciones nuevas durante X semanas.

### 13.3 Catálogo (tus ideas + las mías)

**Dinero**
1. Gasto detectado → categorizar por regla/histórico.
2. Gasto desconocido → preguntar (una sola vez) y aprender.
3. Pago recurrente → detectar suscripción y avisar de subidas.
4. Gasto en hogar → aplicar reparto por defecto.
5. Gasto atípico (> 3× media del comercio) → pedir confirmación.
6. Posible duplicado (mismo importe/comercio/±24 h) → avisar.
7. Presupuesto al 80% → alerta una sola vez al mes.
8. Fin de mes → resumen + "¿liquidamos?".
9. Saldo entre miembros > umbral → recordar liquidar (suave).
10. Suscripción sin uso aparente / próxima renovación → aviso.
11. Objetivo de ahorro → progreso semanal, sugerencia de aportación.
12. Cambio de precio en recurrente → avisar.

**Compras**
13. Compra realizada → actualizar inventario y precio típico.
14. Producto consumido frecuentemente → sugerir añadir.
15. Ticket subido → crear gasto + marcar productos comprados.
16. Lista vacía de "compra semanal" y viernes → sugerir plantilla con habituales.
17. Producto añadido que ya está en la lista → fusionar.

**Tareas y agenda**
18. Evento creado → generar tareas relacionadas (plantillas: cumpleaños → regalo, tarta, invitaciones).
19. Tarea vencida repetidamente → proponer reasignar o reprogramar.
20. Mantenimiento próximo → crear tarea con antelación configurable.
21. Cumpleaños → recordatorio con 7 días para comprar regalo.
22. Tarea asignada a alguien → notificación; sin respuesta en N días → recordatorio.
23. Tarea recurrente completada → crear siguiente según modo (fija/post-completado).
24. Conflicto de agenda detectado → avisar a los afectados.
25. Revisión semanal del domingo → plan de la semana (agenda + tareas + compra).

**Documentos y casa**
26. Documento subido → OCR + extracción + clasificación + sugerir vínculo.
27. Factura recibida → crear obligación + recordatorio de vencimiento.
28. Garantía a 30/7 días de vencer → aviso con documento adjunto.
29. ITV/seguro/revisión → recordatorios escalonados (60/30/7 días).
30. Avería registrada → crear incidencia, sugerir proveedor habitual, adjuntar garantía vigente.
31. Contrato de alquiler/seguro con renovación → aviso de revisar mejores ofertas (cuidado: no vender).
32. Lectura de contador mensual → recordatorio y detección de consumo anómalo.

**Hogar/miembros**
33. Miembro nuevo → checklist de bienvenida y revisión de privacidad.
34. Miembro sale → liquidar saldos, reasignar tareas.
35. Cambio de visibilidad masivo → confirmación C + registro.

**Mascotas/Vehículos**
36. Vacunas/desparasitación → recordatorios según plantilla.
37. Kilometraje registrado → próxima revisión estimada.
38. Repostaje → actualizar consumo medio (L/100 km) y detectar anomalías.

### 13.4 Principios
- Pocas, fiables, explicables > muchas, opacas.
- Notificaciones con presupuesto diario (evitar fatiga); agrupar en resumen.
- Todo se puede silenciar por tipo y por persona.

---

## 14. Arquitectura técnica recomendada

### 14.1 Filosofía
**Monolito modular en TypeScript + Postgres**, extraíble por módulos más adelante. Microservicios desde el día 1 = coste sin beneficio.

### 14.2 Stack propuesto

| Capa | Propuesta | Alternativa | Comentario |
|---|---|---|---|
| Monorepo | pnpm + Turborepo | Nx | Código compartido (tipos, validación, dominio) |
| Lenguaje | **TypeScript** estricto | — | Un solo lenguaje en todo el stack |
| Móvil | **Expo / React Native** | Flutter, PWA | Push, cámara, voz, widgets, atajos nativos |
| Web | **Next.js** (App Router) + Tailwind | Remix, Vite SPA | PWA instalable; escritorio denso |
| UI compartida | Design tokens + componentes (Tamagui/NativeWind) | — | Reutilización móvil/web razonable |
| Estado/datos cliente | TanStack Query + store local (SQLite/MMKV para caché) | — | Optimistic UI |
| Backend | **Servicios de dominio en TS** (Fastify/Hono o NestJS) | Edge Functions | Lógica de negocio independiente del framework |
| API | **REST + OpenAPI** (contrato generado) o tRPC interno | GraphQL | Tipado extremo a extremo; OpenAPI facilita terceros |
| BD | **PostgreSQL** (RLS, jsonb, pgvector, pg_trgm) | — | Núcleo de permisos y búsqueda |
| Hosting inicial | **Supabase** (Postgres+Auth+Storage+Realtime) | Neon + Clerk + S3; Firebase | Rapidez; RLS nativa; portable (es Postgres) |
| Migraciones | SQL versionadas + herramienta (Drizzle/Atlas/sqitch) | Prisma | Revisión humana de migraciones y políticas RLS |
| Auth | Email+OTP/magic link, **passkeys**, Apple/Google | Contraseña | Evitar contraseñas donde se pueda; MFA opcional |
| Archivos | Object storage privado (S3-compatible), URL firmadas de corta duración | — | Cifrado en reposo, antivirus en subida |
| Colas/jobs | Postgres-based (pg-boss/Graphile) al inicio → Redis/SQS si hace falta | — | Menos piezas móviles |
| Tiempo real | Realtime del proveedor / WebSocket por hogar | Polling + push | Compra y tareas lo agradecen |
| Notificaciones | Expo Push / FCM / APNs + email transaccional | — | Preferencias por tipo y horarios silenciosos |
| OCR | **LLM con visión** para tickets; OCR dedicado (Textract, Document AI, Azure DI) para facturas/PDF | Tesseract self-host | Medir coste y precisión; abstracción detrás de interfaz |
| IA | Proveedor LLM detrás de **AI Gateway propio** (prompts versionados, tool calling, evaluación, caché, límites) | — | Sin lock-in |
| Búsqueda | Postgres FTS + `pg_trgm` + **pgvector** | Typesense/Meilisearch | Suficiente hasta mucha escala |
| Observabilidad | OpenTelemetry + Sentry + logs estructurados | — | PII-safe |
| CI/CD | GitHub Actions; entornos dev/staging/prod; previews | — | Tests de aislamiento obligatorios |
| IaC | Terraform/Pulumi (cuando salgas de plataforma gestionada) | — | |

### 14.3 Decisiones críticas y recomendaciones

**¿App nativa o PWA?** La captura rápida (atajos de pantalla de inicio, widgets, voz, cámara, push fiables en iOS, share sheet para "compartir ticket con HomeGest") justifica **app móvil real (Expo)**. Plan pragmático: web (Next.js) y móvil (Expo) comparten dominio, validación y cliente API; la UI se escribe dos veces (componentes compartidos donde convenga). Alternativa de menor coste inicial: PWA primero para validar, Expo cuando se confirme la retención — pero cuidado: el push en iOS y los atajos limitan la hipótesis de "captura sin fricción". **Mi recomendación: Expo desde MVP 1.**

**Offline:** Móvil con *offline-first parcial*: cola de escritura local para captura (gasto, compra, tarea) y lectura cacheada. **No** intentes CRDT/sync bidireccional completo en MVP 1; resolución simple "última escritura gana por campo" con timestamps de servidor, excepto en listas de compra (operaciones por ítem). Reconsiderar (p. ej. PowerSync/ElectricSQL) en V2 si el offline es crítico.

**Multi-tenant:** una base, `space_id` en todo + RLS. Escala lejísima. Aislar por esquema/BD solo para clientes enterprise (no previsto).

**Dinero:** enteros + moneda; sin floats. Conversión de divisas solo informativa en MVP.

**Idempotencia y eventos:** toda captura lleva `client_request_id` (evita duplicados por reintento). Outbox transaccional para eventos → automatizaciones/notificaciones.

**Backups y recuperación:** PITR de Postgres, backups cifrados diarios, restauraciones probadas trimestralmente, RPO ≤ 15 min / RTO ≤ 4 h (objetivo inicial). Archivos: versionado y réplica.

**Escalabilidad (orden de problemas reales):** (1) coste de IA, (2) calidad de OCR/categorización, (3) consultas de agregación (vistas materializadas por hogar/mes), (4) tiempo real, (5) almacenamiento de documentos. La BD no será el cuello de botella en años.

### 14.4 Estructura de repositorio sugerida (para la fase de desarrollo)

```
/apps
  /mobile      Expo
  /web         Next.js
  /api         servicio backend (si no todo en edge)
/packages
  /domain      reglas de negocio puras (permisos, reparto, recurrencia)
  /db          migraciones, políticas RLS, tipos generados, seeds
  /contracts   esquemas Zod/OpenAPI compartidos
  /ai          gateway, prompts, tools, evals
  /ui          design system
  /config      eslint, tsconfig
/docs          discovery, ADRs, runbooks
```
Documentación viva: ADRs (decisiones), diagramas, runbooks, política de privacidad técnica.

---

## 15. Integraciones

### Imprescindible (MVP 1)
| Integración | Uso |
|---|---|
| Sign in with Apple / Google | Registro rápido (requisito de Apple si hay login social) |
| Push (APNs/FCM) + email transaccional | Retención y avisos |
| Proveedor LLM (texto + visión) + STT | Captura IA |
| Almacenamiento de objetos | Fotos de tickets (y documentos después) |
| Exportación/suscripción **ICS** | Convivir con calendarios existentes |
| Pagos de suscripción (**RevenueCat / Stripe**; compras in-app según tienda) | Monetización |

### Recomendable (MVP 2)
| Integración | Nota |
|---|---|
| **Open banking (PSD2)** vía agregador regulado (p. ej. Tink, TrueLayer, Powens, Salt Edge, Enable Banking; GoCardless Bank Account Data *verificar disponibilidad actual*) | Ver abajo |
| Google Calendar (OAuth, bidireccional) y Apple Calendar (EventKit en móvil) | Sync real |
| OCR de documentos (Textract / Document AI / Azure) | Facturas y PDF |
| Compartir hacia la app (share sheet, "reenviar a facturas@…") | Entrada pasiva de documentos |
| Atajos iOS/Android y widgets | Captura en 1 toque |
| Importación CSV/OFX/QIF y Splitwise | Onboarding sin banca |

### Futuro
- Lectura de correo (Gmail/Outlook OAuth, alcance restringido), almacenamiento (Drive/iCloud/Dropbox), Alexa/Google Assistant, domótica, tiendas (tickets digitales/apps de supermercado), Bizum/pagos, proveedores de servicios, aseguradoras, seguros, DGT/ITV.

### Banca: análisis crítico

- **Nunca** se almacenan credenciales bancarias; se usa un **AISP regulado** (OAuth/consentimiento del banco). Se guardan solo *tokens/IDs de consentimiento* cifrados, nunca usuario/contraseña.
- **Consentimiento PSD2:** renovación periódica (típicamente ~180 días/90 según banco/regulación): hay que diseñar UX de reconexión.
- **Coste:** los agregadores cobran por conexión/cuenta activa; compromete el margen del plan gratuito → banca solo en plan de pago (o créditos).
- **Calidad de datos:** comercios con nombres crípticos ("COMPRA TARJ. *1234 MERCADONA 0021"), pendientes vs. contabilizados, duplicados, retrasos. La limpieza es producto en sí.
- **Cobertura y fiabilidad por banco** en España/UE es desigual; riesgo de dependencia de terceros.
- **Alternativa de captura pasiva barata (hipótesis a validar):** en iOS, Atajos puede disparar una automatización al pagar con una tarjeta de Wallet y pasar importe/comercio a la app; en Android, lectura de notificaciones bancarias (con permiso explícito y cuidado con políticas de Play). Esto da "casi automático" **sin** open banking. Validar viabilidad técnica y de política de tiendas antes de prometerlo.
- **Decisión:** MVP 1 sin banca; en paralelo, hacer un **spike** (1 semana) con un agregador en sandbox para medir coste, cobertura y calidad antes de comprometer el plan de precios.

---

## 16. Seguridad y cumplimiento

### 16.1 Autenticación
- Passkeys + magic link/OTP; Apple/Google; contraseña opcional con hash Argon2id si se admite.
- Sesiones cortas con refresh rotatorio; revocación por dispositivo; detección de inicio de sesión inusual.
- MFA (TOTP/passkey) recomendado; **obligatorio para acciones críticas** (exportar todo, eliminar hogar, conectar banca).
- Anti-abuso: rate limiting, protección de invitaciones (tokens aleatorios de un solo uso/expiran, hashed at rest).

### 16.2 Autorización
- Deny-by-default; RLS en BD + comprobaciones de dominio en el servicio (defensa en profundidad).
- `space_id` derivado **del token/sesión + membership**, nunca confiado desde el cliente.
- Pruebas automáticas "cross-tenant": para cada tabla, un test que verifica que usuario de hogar A no lee/modifica/inserta en hogar B, ni lo privado de un compañero.
- Revisión de políticas RLS como código (PR obligatorio + tests) y *linter* de tablas sin RLS en CI.

### 16.3 Cifrado y datos financieros
- TLS 1.2+/HSTS; cifrado en reposo (BD, backups, objetos).
- **Cifrado a nivel de campo** para datos de alta sensibilidad (tokens de agregador, números de póliza/IBAN completos si se almacenan) con claves en KMS, rotación.
- Minimizar: guardar `last4`, no PAN; no almacenar CVV nunca; evitar IBAN completo si no es necesario.
- Secretos en gestor de secretos; ningún secreto en repo; escaneo de secretos en CI.
- Apps móviles: almacenamiento seguro (Keychain/Keystore), bloqueo biométrico opcional, ofuscar capturas en el selector de apps.

### 16.4 Documentos privados
- Bucket privado; acceso solo vía URL firmada de corta vida generada tras comprobar permisos.
- Antivirus/validación de tipo y tamaño en subida; sin ejecución de contenido.
- OCR/IA sobre documentos sensibles (DNI, sanitarios): opt-in explícito, proveedor con retención cero, opción de "no procesar con IA".

### 16.5 Logs y auditoría
- `AuditLog` append-only: quién, qué, cuándo, desde dónde; cambios de permisos, exportaciones, accesos a documentos sensibles, acciones del asistente.
- Logs de aplicación **sin PII** (ni importes ni descripciones en claro); trazas con IDs.
- El usuario puede ver su propia actividad ("Mi actividad") y los cambios de visibilidad que le afectan.

### 16.6 Privacidad y RGPD (UE/España)
- Base legal: ejecución de contrato + consentimiento para IA/analítica/banca.
- **DPA** con subencargados (IA, hosting, OCR, push); transparencia de qué se envía a IA.
- Región UE para datos; transferencias internacionales con garantías (SCC) cuando aplique.
- **Evaluación de impacto (DPIA)** recomendable (datos financieros, menores, perfiles).
- Datos de menores: consentimiento del tutor; mínima recogida; sin analítica publicitaria.
- Derechos: acceso/portabilidad (exportar JSON/CSV + archivos), rectificación, supresión, oposición.
- Retención y borrado: ver abajo.

### 16.7 Eliminación y exportación
- **Exportación** completa por usuario y por hogar (JSON/CSV + ZIP de archivos); el hogar exige permiso de owners; cada usuario exporta *lo suyo*.
- **Eliminación:** borrado lógico 30 días (periodo de gracia) → purga física (BD, objetos, índices vectoriales, copias de IA). Backups caducan en su ciclo (documentar plazo).
- Salida de un miembro: datos privados exportables y eliminados; compartidos permanecen con atribución anonimizable.
- Eliminación de hogar: confirmación C + notificación a miembros + periodo de gracia.

### 16.8 Amenazas específicas a considerar
- **Control coercitivo / abuso en pareja:** diseñar para que nadie pueda ver lo privado de otro, que salir de un hogar sea fácil, sin "modo vigilancia", y alertas visibles cuando se concede acceso.
- Enumeración de invitaciones; secuestro de hogar por invitación; ingeniería social.
- Prompt injection vía documentos/correos/ticket.
- Exfiltración por exportaciones; abuso de enlaces compartidos.
- Dependencia de proveedores: plan de contingencia (caída de IA → captura manual sigue funcionando).

### 16.9 Madurez
- Pentest externo antes del lanzamiento público con dinero real; política de divulgación responsable; objetivos hacia SOC 2/ISO 27001 solo si se vende a terceros/B2B.

---

## 17. Riesgos técnicos y de producto

| # | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| R1 | **Alcance excesivo** (todo a la vez) | Alta | Alto | MVP cerrado, criterios de salida por fase, lista "NO" (§21) |
| R2 | **El segundo miembro no se activa** (efecto red) | Alta | Crítico | Valor útil en solitario (captura, recordatorios), invitación en 1 toque, onboarding por pareja, listas compartidas como gancho |
| R3 | Fallos de **privacidad/permisos** (fuga entre miembros u hogares) | Media | Crítico | RLS, tests de aislamiento, revisión de seguridad, defaults privados |
| R4 | **Calidad de IA** en español informal (ambigüedad, comercios, importes) | Alta | Alto | Golden sets, confirmaciones graduales, reglas explícitas, métricas, fallbacks manuales |
| R5 | **Coste de IA y OCR** por usuario | Media | Alto | Modelos pequeños para rutas frecuentes, caché, límites por plan, medir coste/hogar desde el día 1 |
| R6 | **Open banking**: coste, cobertura, mantenimiento, regulación | Alta | Alto | Posponer a MVP 2, spike, plan de pago, abstracción de proveedor |
| R7 | Retención baja (app de "registro" que da pereza) | Alta | Alto | Hoy útil, notificaciones valiosas, captura pasiva, resumen semanal/mensual |
| R8 | **Fatiga de notificaciones** | Media | Medio | Presupuesto de avisos, digest, preferencias |
| R9 | Complejidad de **reparto de gastos** (casos límite, redondeos, monedas) | Media | Medio | Modelo simple (iguales/porcentajes/importes), enteros, tests de propiedad |
| R10 | **Sincronización/offline** y conflictos | Media | Medio | Operaciones por ítem, idempotencia, MVP con alcance limitado |
| R11 | Competencia de **gigantes** (Google/Apple) o apps verticales maduras (Splitwise, Cozi…) | Media | Alto | Foco en integración + IA + privacidad; nicho parejas; velocidad |
| R12 | **Regulatorio**: RGPD, menores, PSD2, IA (AI Act) | Media | Alto | DPIA, asesoría legal, no actuar como entidad financiera, transparencia de IA |
| R13 | **Dependencia de proveedores** de IA/banca/hosting | Media | Medio | Capas de abstracción, contratos, plan B |
| R14 | Uso en contextos de **control/abuso** | Baja-Media | Crítico (ético) | Diseño de privacidad firme (§9, §16.8), sin "ver todo" para admins |
| R15 | **Deuda técnica** por velocidad (permisos mal hechos) | Alta | Alto | Permisos y migraciones bien desde la fase 0; refactor planificado |
| R16 | Monetización: **disposición a pagar** baja en apps familiares | Media | Alto | Valor premium claro (banca/documentos/IA), precio por hogar, pruebas de precio |
| R17 | **Plataformas** (reglas de App Store/Play sobre pagos, notificaciones, IA) | Media | Medio | Revisar políticas pronto, usar IAP, ocultar funcionalidades condicionadas |
| R18 | Calidad y privacidad de **OCR** (documentos sensibles a terceros) | Media | Alto | Opt-in, proveedores UE/retención cero, procesamiento local si es viable |
| R19 | Problema "**gran hermano**" percibido (mala prensa/rechazo) | Media | Medio | Mensajería de privacidad clara, controles visibles |

**Mayor riesgo oculto:** construir un producto de *registro* (da trabajo) en vez de uno de *resultado* (te ahorra trabajo). Si el usuario tiene que mantenerlo, fracasa. La IA y la captura pasiva son lo que lo evita.

---

## 18. Diferenciación y competencia

### 18.1 Panorama (categorías, sin exhaustividad)

| Categoría | Ejemplos representativos | Fortaleza | Hueco |
|---|---|---|---|
| Gastos compartidos | Splitwise, Tricount | Reparto de gastos simple y viral | Solo dinero; sin hogar ni tareas; IA limitada; privacidad básica |
| Finanzas personales / presupuestos | YNAB, Monarch, Copilot, Fintonic, Bankin' | Banca, presupuesto, análisis | Pensadas para individuo/pareja financiera; poco "hogar"; curva alta |
| Organizadores familiares | Cozi, FamilyWall, OurHome, Maple, Picniic | Calendario + listas + tareas familiares | Sin finanzas reales ni documentos; permisos simples; IA escasa |
| Listas de compra | Bring!, AnyList, OurGroceries | Compra en tiempo real, muy pulidas | Aisladas del gasto/inventario |
| Tareas / productividad | Todoist, Things, TickTick, Notion | Potencia en tareas | No hogar, no dinero; Notion exige construir todo |
| Tareas del hogar | Tody, Sweepy, Nipto, Chorma | Rotación y limpieza | Nicho; sin dinero |
| Calendario | Google/Apple/Outlook | Ubicuidad | Datos aislados; sin contexto de hogar |
| Documentos | Paperless-ngx, Evernote, Drive, Dropbox | Archivo y OCR | Sin vencimientos/entidades ni hogar; técnico |
| Gestión de vivienda/vehículos | HomeZada, Centriq, apps de vehículo (Fuelio, Drivvo) | Detalle vertical | Verticales; pocos usuarios españoles |
| Asistentes IA generalistas | ChatGPT, Gemini, Siri | Lenguaje natural | **Sin datos del hogar ni acciones de dominio** |

> Los nombres son ilustrativos del tipo de producto; conviene un estudio competitivo real (funcionalidades, precios, reseñas) antes de decidir posicionamiento final.

### 18.2 El hueco

Nadie cubre bien **la intersección**: *dinero compartido + logística diaria + papeles de la casa* con:
1. **Un modelo de hogar flexible** (pareja, piso, familia, cuidadores).
2. **Privacidad granular real** (lo personal convive con lo compartido).
3. **Un asistente con acceso a datos propios del hogar** y capacidad de actuar.
4. **Captura casi pasiva** (voz, foto, atajos, banca opcional).

### 18.3 Posicionamiento
- No "una app de finanzas", ni "otro calendario". **"El copiloto del hogar."**
- Lema tentativo: *"Dilo. Yo me ocupo."* / *"Tu casa, sin cabos sueltos."*
- Mercado inicial: **España/UE hispanohablante** (idioma, bancos, RGPD, hábitos como Bizum, ITV, IBI) — una ventaja local frente a apps anglosajonas.

### 18.4 Moats (defendibilidad)
- Datos y reglas aprendidas del hogar (coste de cambio crece con el uso).
- Archivo de documentos y vencimientos (ancla).
- Efecto red intra-hogar y entre hogares (invitar a la familia, compañeros).
- Calidad de IA en español local (comercios, jerga, trámites).
- Confianza en privacidad como marca.

### 18.5 Lo que NO es diferenciador (no invertir como si lo fuera)
- Gráficos bonitos, gamificación, recetas, "otro to-do".

---

## 19. Ejemplos concretos de flujos de usuario

### F1. Gasto por voz (MVP 1)
1. Pablo pulsa **＋** (o atajo/widget) y dice: *"Compré 35 de gasolina"*.
2. STT → Router → `create_transaction{amount:3500, currency:EUR, category:Combustible(sugerida), date:hoy, account:Tarjeta Pablo(por defecto), visibility:hogar, merchant:null}`.
3. Confianza alta (regla "gasolina → Combustible") → nivel A: guardado con "Hecho · Deshacer". Aparece en Hoy.
4. Si faltara el comercio, se mantiene como "sin comercio" sin preguntar (no interrumpir por datos opcionales).

### F2. Foto de ticket (MVP 1)
1. ＋ → cámara → foto.
2. Visión extrae: comercio (MERCADONA), fecha, total 43,20, líneas (opcional).
3. Tarjeta de confirmación con los campos y categoría sugerida **Supermercado** (regla); se confirma con un tap.
4. Reparto por defecto 50/50 con Marta; aparece en el saldo.
5. Si hay lista de compra abierta, ofrece "Marcar como comprados los productos de la lista".

### F3. Gasto desconocido (bandeja)
1. Se registra "CAFETERIA LA PLAZA 12,50" (foto/banca).
2. No hay regla → el gasto queda en **Por revisar** y llega una notificación agrupada: *"He detectado 12,50 € en LA PLAZA. ¿Qué tipo de gasto es?"* con chips (Restaurantes/Café, Ocio, Otro…).
3. El usuario toca "Cafés y bares" → se guarda y pregunta una vez: "¿Aplicar siempre a LA PLAZA?".
4. La regla se crea; la próxima vez es automático (A).

### F4. Lista de compra colaborativa (MVP 1)
1. Marta añade "café" y "papel higiénico" desde la lock screen/atajo/voz.
2. Pablo, en el súper, abre **Modo tienda**; ve los dos items instantáneamente.
3. Marca "café ✓" → Marta ve el tachado en tiempo real.
4. Al terminar, "Cerrar compra" → ofrece crear gasto (importe) y reparto.

### F5. Tarea doméstica recurrente y justa (MVP 1)
1. Crear "Sacar la basura": cada 2 días, responsable alternado Pablo/Marta (rotación en V2; en MVP asignación manual).
2. Hoy muestra a cada uno lo suyo.
3. Al completar, se crea la siguiente instancia y se actualiza la vista "Carga de tareas" (sin puntos).

### F6. Consulta al asistente (MVP 1)
1. "¿Cuánto hemos gastado este mes en restaurantes?"
2. `query_transactions(category=Restaurantes, period=month, space=household)` bajo permisos del usuario.
3. Respuesta: "**312,40 €** (15 movimientos). 18% más que septiembre. [Ver movimientos]". Si hay gastos privados de Marta, **no se incluyen** y se indica "solo lo que puedes ver".

### F7. Acción con confirmación (MVP 1)
1. "Recuérdame llevar el coche al taller el jueves y asígnaselo a Pablo."
2. El asistente propone una tarjeta: *Tarea · Llevar coche al taller · Pablo · jueves 9:00 · recordatorio 1 h antes* [Confirmar/Editar].
3. Pablo recibe la notificación; el historial muestra "creado por Marta con el asistente".

### F8. Documento + garantía (MVP 2)
1. Foto de factura de lavadora (o reenvío por email).
2. OCR → emisor, fecha, importe, modelo; detecta garantía de 3 años → crea `Warranty` hasta 2029-10-03 y recordatorio a 30 días.
3. Sugiere vincular al **Asset** "Lavadora" (la crea si no existe) y registra el gasto si no estaba.
4. Más tarde: *"Enséñame la garantía de la lavadora"* → abre el documento y muestra el vencimiento.

### F9. Avería (MVP 2)
1. "Se ha roto el aire acondicionado."
2. Propuesta: incidencia sobre Asset "Aire acondicionado" · prioridad alta · responsable (tú) · proveedor habitual "Climatización López" · garantía vigente adjunta.
3. Se añaden presupuesto, fecha de reparación y factura; al pagar, se vincula el gasto.

### F10. Alta del hogar e invitación (MVP 1) — *flujo crítico para activación*
1. Marta se registra → crea "Casa Marta y Pablo" (un nombre; sin formularios largos).
2. Pantalla: "Invita a Pablo" → compartir enlace (WhatsApp/SMS).
3. Mientras tanto Marta ya puede usar la app (gasto, compra).
4. Pablo abre el enlace → instala/entra → ve ya la lista de compra con items → se activa.
5. Pantalla de privacidad al entrar: *"Esto es lo que ve el hogar / esto es privado"* con defaults seguros.

### F11. Salida de un miembro (MVP 1 simple)
1. Compañero de piso se va: se le ofrece **liquidar saldos** y exportar sus datos.
2. Sus tareas pendientes se reasignan; su historial queda con atribución (o anonimizado si lo pide).

### F12. Compartir algo privado con una persona (MVP 2)
1. Marta abre un documento privado (seguro de vida) → Compartir → elige "Solo Pablo (lectura)".
2. Pablo recibe notificación; el acceso aparece en "Actividad" y se puede revocar en un toque.

---

## 20. Estrategia de desarrollo por fases

Cada fase se ejecuta con el ciclo que pediste: **explicar → criterios de aceptación → implementar → revisar → detectar problemas → corregir → continuar**. Cada fase termina con demo, tests en verde, migraciones aplicadas y documentación actualizada.

### Fase 0 — Cimientos (1–2 semanas)
**Construir:** monorepo, CI, entornos, esquema base (`User`, `Space`, `Membership`), Auth, **RLS + helpers de permisos + suite de aislamiento**, design tokens, esqueleto móvil/web, observabilidad básica, ADRs.
**Aceptación:**
- Registro/login con magic link y Apple/Google.
- Crear hogar; usuario A de hogar X no puede leer nada de hogar Y (tests automáticos).
- CI: lint, typecheck, tests, chequeo "toda tabla tiene RLS".
- Migraciones reproducibles desde cero.
**Spikes en paralelo (decisión informada):** (1) agregador bancario sandbox; (2) captura de gasto con LLM sobre 100 frases/tickets reales en español (precisión y coste); (3) atajos de Wallet en iOS.

### Fase 1 — Hogar y personas (1–2 semanas)
**Construir:** invitaciones, roles básicos, perfiles, selector de contexto Personal/Hogar, exportación/eliminación básica.
**Aceptación:** invitar por enlace en < 30 s; segunda persona entra y ve datos compartidos; salir del hogar funciona; auditoría de eventos de membresía.

### Fase 2 — Compra (1–2 semanas)
**Construir:** listas, items, tiempo real, modo tienda, offline básico de captura.
**Aceptación:** latencia de sincronización percibida < 2 s; añadir un producto en ≤ 3 s; conflictos resueltos por ítem; tests de concurrencia.
*(Primero la compra porque es el gancho de adopción del 2º miembro y el módulo más sencillo para validar tiempo real y permisos.)*

### Fase 3 — Tareas y Agenda (2–3 semanas)
**Construir:** tareas (responsable, prioridad, fecha, recurrencia, subtareas, comentarios), eventos, ICS, recordatorios y push.
**Aceptación:** recurrencias correctas (tests con zonas horarias y DST); notificaciones fiables; Hoy muestra lo del día.

### Fase 4 — Dinero núcleo (2–3 semanas)
**Construir:** cuentas/tarjetas (sin banca), categorías, gasto manual, reparto, saldos, liquidación, bandeja "por revisar", memoria de comercio.
**Aceptación:** propiedades de reparto (suma de splits = total, redondeo determinista); saldos coherentes tras edición/borrado; privacidad de cuentas e ingresos verificada con tests.

### Fase 5 — Asistente y captura (2–3 semanas)
**Construir:** gateway de IA, captura texto/voz/foto, router de intención, herramientas de lectura/escritura, política de confirmación, "Deshacer", reglas aprendidas, evals.
**Aceptación:** ≥ 90% de acierto de intención en golden set; ≥ 85% de importes/fechas correctos; 0 fugas entre miembros en pruebas adversariales (prompt injection); coste/hogar medido.

### Fase 6 — Hoy + pulido + beta cerrada (2 semanas)
**Construir:** widgets Hoy, onboarding, accesibilidad, rendimiento, analítica de producto respetuosa con privacidad, política de privacidad/ToS, pentest ligero.
**Aceptación:** 20–50 hogares reales de prueba; métricas de §7; crashes < 1%; checklist de seguridad cerrado.

### Fase 7+ — MVP 2
Documentos+OCR → Assets y vencimientos → Banca (premium) → Presupuestos/objetivos → Permisos finos y grupos → Sync de calendario → Widgets configurables.

> **Regla:** no se empieza una fase sin cerrar la anterior (tests, revisión, deuda anotada). Cada 2 fases: revisión de producto con datos reales.

---

## 21. Monetización

### 21.1 Principios
- Sin publicidad invasiva ni venta de datos (promesa de marca y ventaja competitiva).
- **Precio por hogar**, no por usuario (evita fricción de invitar).
- Gratis útil: lo suficiente para que el hogar se active y el efecto red funcione.
- Cobrar por lo que **cuesta dinero** (banca, IA intensiva, OCR/almacenamiento) y por **conveniencia avanzada**.

### 21.2 Opciones evaluadas

| Modelo | Pros | Contras | Veredicto |
|---|---|---|---|
| Freemium por hogar | Crecimiento, efecto red, bajo riesgo de adopción | Conversión típica 2–5% (hipótesis) | **Recomendado** |
| Suscripción individual | Simple | Penaliza compartir | No |
| Suscripción familiar plana | Predecible, alinea con "hogar" | Menos ingresos en hogares grandes | **Recomendado (base)** |
| Pago por uso (IA/banca) | Alinea coste | Complejidad, ansiedad de gasto | Solo como límites/créditos suaves |
| Almacenamiento premium | Coste ligado a uso | Poco atractivo solo | Incluido en plan |
| Compra única (lifetime) | Caja inicial | Riesgo con costes recurrentes de IA/banca | Evitar |
| Marketplace/afiliación (seguros, energía) | Ingresos pasivos | Conflicto de interés, erosiona confianza | Solo con transparencia y opt-in; **no antes de V2** |
| B2B2C (aseguradoras, bancos, gestorías) | Escala | Ciclos largos, pierde independencia | Futuro |

### 21.3 Planes sugeridos (hipótesis de precio; testear)

| | **Gratis** | **Hogar Plus** (~4–7 €/mes por hogar) | **Hogar Pro / Familia ampliada** (~9–12 €/mes) |
|---|---|---|---|
| Miembros | hasta 2–3 | hasta 6 | hasta 10+ |
| Gastos, compra, tareas, agenda | ✔ | ✔ | ✔ |
| Captura IA | cuota mensual limitada | amplia | muy amplia |
| Historial | 12 meses | ilimitado | ilimitado |
| Documentos | 1 GB, sin OCR avanzado | OCR + búsqueda semántica, 10 GB | 50 GB |
| Banca automática | ✘ | 1–2 conexiones | ilimitadas razonables |
| Presupuestos/objetivos | básicos | ✔ | ✔ |
| Permisos finos/grupos | ✘ | ✔ | ✔ |
| Automatizaciones personalizadas | ✘ | limitadas | ✔ |
| Soporte | comunidad | email | prioritario |

- Prueba gratuita de 14 días del plan de pago sin tarjeta (activación antes de pedir dinero).
- Descuento anual (~2 meses gratis).
- Unit economics: estimar **coste IA + banca + almacenamiento por hogar activo** desde el día 1; objetivo de margen bruto > 70% en hogares de pago.
- Comisiones de tiendas (15–30% según programa): considerar al fijar precio.

### 21.4 Palancas de crecimiento
- Invitación natural (cada hogar trae 1–3 usuarios).
- Importadores (Splitwise/CSV) y plantillas por tipo de hogar.
- Contenido "resumen mensual del hogar" compartible (sin datos sensibles).
- Programa de referidos por hogar.

---

## 22. Qué NO construir inicialmente (y por qué)

| No construir (todavía) | Razón |
|---|---|
| **Open banking en MVP 1** | Coste, regulación, mantenimiento y calidad de datos; puede validarse con captura manual/IA |
| **Comidas/recetas/menús** | Producto en sí mismo; mercado saturado; el valor sobre compra es marginal al inicio |
| **Inventario completo** | Se abandona por esfuerzo; mejor derivarlo de compras (V2) |
| **Gamificación** (puntos, rachas, medallas, ranking) | Riesgo de trivializar, competir y generar conflicto; ver abajo |
| **Motor de automatización configurable por el usuario** | Construir primero 10 automatizaciones fijas excelentes |
| **Permisos ultra-granulares en UI** | Modelo sí; UI de matrices complejas confunde (MVP 2) |
| **Sync bidireccional de calendario** | Costoso de mantener; ICS cubre 80% del valor |
| **Lectura de correo** | Superficie de privacidad y OAuth sensibles |
| **Pagos / transferencias dentro de la app** | Regulación financiera; riesgo |
| **Cuentas para menores** | RGPD reforzado; perfiles sin cuenta suficientes |
| **IA proactiva intensa / chat omnipresente** | Ruido; primero utilidad en tareas concretas |
| **App de escritorio nativa** | La web responsive/PWA cubre el caso |
| **Marketplace, afiliación, comparadores** | Conflicto de interés; erosiona la confianza |
| **Multi-divisa avanzada, inversiones, impuestos** | Otro producto distinto |
| **Colaboración tipo Notion (docs ricos)** | Desvía del foco |
| **Estadísticas elaboradas** | Cuatro gráficos útiles > veinte decorativos |
| **Módulo "Notas" completo** | Existe en todos los móviles; nota = documento ligero o campo |

### Gamificación: análisis crítico

**Dónde puede aportar valor (poco, y con cuidado):**
- **Visibilidad justa del reparto de carga** (qué ha hecho cada uno): reduce discusiones. *No* es gamificación; es transparencia.
- **Progreso hacia objetivos** (ahorro, vacaciones): una barra de progreso es motivadora y útil.
- **Hábitos del hogar** para niños (tareas con recompensa pactada por los padres): V2/Futuro, **opt-in** y configurable por la familia.
- Confirmaciones satisfactorias y microinteracciones al completar tareas (feedback, no juego).

**Dónde es contraproducente:**
- Puntos/ranking entre adultos: genera competencia, resentimiento y "hacer tareas para puntuar".
- Rachas diarias: ansiedad y abandono tras romperse; encaja mal con tareas del hogar irregulares.
- Recompensas monetarias entre miembros: conflicto, distorsiona motivaciones.
- Insignias por registrar gastos: incentivos vacíos.

**Conclusión:** MVP 1–2 sin gamificación. Mantener "carga de tareas" y progreso de objetivos. Evaluar un modo "Familia con niños" (opt-in) en V2 solo si hay demanda.

---

## 23. Recomendaciones finales y decisiones que necesito de ti

### 23.1 Lo que más cambiaría de tu planteamiento
1. **Recorta el MVP a Dinero compartido + Compra + Tareas + Agenda + Asistente de captura.** Documentos y Assets llegan en MVP 2 como "el ancla de retención".
2. **Unifica vehículos/mascotas/vivienda/electrodomésticos en `Asset`** y mantenimiento/incidencias en `Task`.
3. **Aplica permisos en la base de datos (RLS)** y haz que **el asistente use la identidad del usuario**.
4. **Aplaza la banca**; valida antes con captura IA + (si es viable) atajos de Wallet.
5. **Empieza por parejas** en España, con la invitación del 2º miembro como flujo crítico.
6. **Gamificación casi cero.**
7. **Mide desde el día 1** coste de IA por hogar y activación del segundo miembro.

### 23.2 Preguntas abiertas (necesito tu decisión antes de la Fase 0)

1. **Mercado y idioma inicial:** ¿España/UE en español como foco? ¿Moneda inicial EUR?
2. **Equipo y plazos:** ¿desarrollo en solitario o equipo? ¿Cuántas horas/semana? Condiciona stack y alcance (Expo vs. PWA).
3. **Plataforma de lanzamiento:** ¿iOS + Android desde el inicio o iOS primero? ¿Solo web en una primera beta?
4. **Backend:** ¿ok con **Supabase** (Postgres + Auth + Storage + RLS) como base inicial, o prefieres backend propio desde el principio?
5. **Proveedor de IA:** ¿preferencia (Anthropic, OpenAI, Google) o restricciones de datos/región?
6. **Segmento de arranque:** ¿confirmas **parejas** como primer usuario? ¿Eres tú mismo usuario (dogfooding)?
7. **Banca:** ¿aceptas posponerla a MVP 2 y hacer solo un spike ahora?
8. **Monetización:** ¿proyecto de negocio con ingresos o producto personal/familiar primero?
9. **Menores:** ¿aceptas "perfiles sin cuenta" para hijos en el MVP?
10. **Nombre y marca:** ¿se mantiene "HomeGest"? (Revisar disponibilidad de dominio y marca.)
11. **Datos de ejemplo:** ¿puedes aportar 20–50 frases/tickets reales (anonimizados) para el golden set de IA?

### 23.3 Siguiente paso propuesto
1. Revisas este documento y respondes §23.2 (aunque sea parcialmente).
2. Yo convierto lo acordado en: **ADR-001 (stack)**, **especificación de Fase 0 con criterios de aceptación**, y el **esquema SQL + políticas RLS inicial** para tu revisión antes de escribir cualquier código de aplicación.
3. Arrancamos Fase 0.

---

### Apéndice A — Tabla de fase por funcionalidad (justificación resumida)

| Funcionalidad | Fase | Justificación |
|---|---|---|
| Hogar, invitaciones, roles base | MVP 1 | Sin multiusuario no hay producto |
| Privado/Hogar | MVP 1 | Confianza desde el inicio |
| Gastos + reparto + saldos | MVP 1 | Dolor principal y mayor disposición a pagar |
| Captura IA texto/voz/foto | MVP 1 | Diferenciador y valor de uso diario |
| Compra compartida en tiempo real | MVP 1 | Gancho de adopción del 2º miembro |
| Tareas y recurrencia simple | MVP 1 | Uso diario y carga justa |
| Agenda + ICS | MVP 1 | Contexto diario sin sync complejo |
| Hoy | MVP 1 | Home y percepción de valor |
| Documentos + OCR | MVP 2 | Ancla de retención; requiere pipeline de IA/OCR |
| Assets (vehículo, mascota, vivienda) | MVP 2 | Generaliza gastos/documentos/mantenimiento |
| Vencimientos y garantías | MVP 2 | Valor alto con Assets+Docs |
| Banca | MVP 2 | Premium, coste/riesgo |
| Presupuestos/objetivos | MVP 2 | Útil sobre histórico de gastos |
| Permisos finos/grupos | MVP 2 | Modelo ya soportado; UI cuando haya casos reales |
| Widgets configurables | MVP 2 | Primero conjunto fijo bien ordenado |
| Suscripciones detectadas | V2 | Necesita histórico/banca |
| Reglas de usuario | V2 | Evitar motor genérico prematuro |
| Despensa/hábitos de compra | V2 | Requiere histórico |
| Correo | V2 | Riesgo de privacidad |
| Sync calendario bidireccional | V2 | Mantenimiento costoso |
| Cuentas de adolescentes / modo cuidador | V2 | Cumplimiento y UX específicos |
| Comidas/recetas | Futuro | Producto distinto, mercado saturado |
| Pagos integrados | Futuro | Regulación |
| API pública / marketplace | Futuro | Prematuro |
| Gamificación (niños) | Futuro | Opt-in, sin evidencia aún |

### Apéndice B — Principios de diseño visual (resumen; el sistema completo se definirá en Fase 0)

- **Tono:** cálido, sereno, confiable (dinero + casa). Evitar estética "fintech fría" y "infantil".
- **Color:** neutros cálidos + 1 color de marca + semánticos (éxito, aviso, error); color por miembro (con patrón/inicial para accesibilidad); modo oscuro desde el inicio.
- **Tipografía:** sans geométrica legible (Inter/Plus Jakarta/Manrope), cifras tabulares para importes.
- **Espaciado/rejilla:** base 4/8 px; áreas táctiles ≥ 44 px (≥ 56 px en modo tienda).
- **Componentes base:** tarjeta, fila de lista, chip, hoja inferior (bottom sheet), campo de captura, avatar de miembro, badge, estado vacío útil, skeleton, toast con "Deshacer".
- **Interacción:** gestos (swipe), teclado numérico para importes, valores por defecto inteligentes, confirmaciones reversibles en lugar de diálogos.
- **Accesibilidad:** WCAG 2.2 AA, escalado de texto, lector de pantalla, no depender solo del color.
- **Importes:** negativos/positivos con signo + color + texto; formato regional (1.234,56 €).
- **Iconografía:** conjunto único con trazo uniforme; ilustración mínima.
- **Movimiento:** breve y funcional (≤ 200 ms), respetando "reducir movimiento".
- **Vacíos y errores:** siempre con siguiente paso claro.

### Apéndice C — Métricas de producto (norte y guardarraíles)

- **Activación:** hogar con ≥ 2 miembros y ≥ 3 registros en 7 días.
- **Hábito:** capturas/semana por hogar; % por voz/foto; tiempo medio de captura.
- **Calidad IA:** % aceptación sin edición, % corregido, % "por revisar", latencia, coste/hogar.
- **Retención:** D7/D30/D90 por hogar (no por usuario).
- **Confianza:** incidentes de permisos = 0; solicitudes de exportación/eliminación atendidas < 30 días.
- **Negocio:** conversión a pago, ARPU por hogar, margen bruto, churn.
