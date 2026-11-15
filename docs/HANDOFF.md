# HomeGest — Traspaso de contexto

> Para continuar el trabajo en un entorno local con acceso al NAS del usuario. Redactado el 2026-11-15 a partir de la conversación completa.
> **No contiene secretos.** La clave de Gemini que el usuario pegó en el chat se considera comprometida; debe revocarla y crear otra. Nunca la guardes en el repositorio.

Repositorio: `JohnSM7/HomeGest` · Rama de trabajo: `claude/compassionate-fermi-q5f9fl` (no se ha creado ningún PR).

---

## 1. Qué se está construyendo

Una plataforma web (PWA móvil) de gestión personal y compartida, pensada como "sistema operativo del hogar". La unidad es el **grupo** (piso, pareja, familia, viaje, evento, trabajo), no solo "hogar". Cada persona tiene su espacio personal y puede estar en varios grupos. Módulos del MVP: **gastos con reparto, compra compartida, tareas, agenda** y un **asistente de IA** que captura gastos y responde preguntas. La IA ejecuta acciones con confirmación, y el diferenciador es la **captura instantánea de gastos desde las notificaciones del banco**.

Documentos de referencia (todos en `docs/`):

| Archivo | Contenido |
|---|---|
| `PRODUCT_DISCOVERY.md` | Discovery completo (20 puntos): visión, MVP, permisos, modelo de datos, IA, riesgos, monetización |
| `adr/ADR-001-stack.md` | Stack: PWA + Next.js + Supabase + Gemini |
| `adr/ADR-002-groups.md` | Grupos libres, invitaciones, participantes sin cuenta |
| `PHASE_0.md` | Especificación y estado de la Fase 0 |
| `AI_AND_CAPTURE.md` | Qué usa IA, flujo "registrar gasto", captura por notificación, formato BBVA, tipos de aviso, notas de despliegue |
| `fixtures/bbva-notifications.json` | Muestras reales anonimizadas de avisos BBVA |
| `design/mockup-v1.html`, `design/mockup-v2.html` | Prototipos visuales (el v2 es navegable y es el vigente) |

## 2. Usuario y forma de trabajar

- Habla **español**. Es informático (trabaja por cuenta ajena y tiene su propia consultora como autónomo). Desarrolla **en solitario, a tiempo parcial**.
- Pidió desde el principio: ser **crítico**, proponer mejores estructuras, no limitarse a ejecutar ideas, **no programar a lo loco**, trabajar **por fases** con este ciclo: explicar → criterios de aceptación → implementar → revisar → detectar problemas → corregir → siguiente. Prioridades: código mantenible, seguridad, UX, arquitectura limpia, componentes reutilizables, tipado, tests, migraciones, documentación.
- Quiere una interfaz **moderna, fluida y agradable** ("el primer mockup se veía muy básico"). Valida con prototipos antes de construir.
- **No crear Pull Requests** salvo que lo pida. Desarrollar y empujar solo en la rama indicada.
- Commits terminan con las líneas de atribución que indique el entorno.

## 3. Decisiones confirmadas

| Tema | Decisión |
|---|---|
| Mercado | España, EUR |
| Plataforma | **PWA** móvil-first (no app nativa de momento). Podría envolverse con Capacitor o hacerse una mini app Android solo para leer notificaciones si MacroDroid resulta frágil (ADR-003 pendiente) |
| Stack | Next.js (App Router) + TypeScript estricto + Tailwind + shadcn/ui; un solo repo, una sola app; Postgres con RLS; Vitest, pgTAP, Playwright |
| Backend | **Supabase autoalojado en el NAS del usuario** (antes se propuso Supabase en la nube) |
| IA | **Gemini** (acceso de pago por privacidad de datos), solo desde servidor, tras un módulo propio `lib/ai`. El modelo nunca escribe en BD: propone → el servidor valida → confirmación según política |
| Dinero | Enteros en céntimos + moneda; reparto por método del resto mayor (la suma de partes = total) |
| Unidad | Grupos libres con plantilla opcional (`home, couple, family, trip, event, work, other`) y módulos activables. Sin buscador de usuarios; invitación por enlace (código corto y QR más adelante) |
| Gamificación | Prácticamente ninguna. Solo reparto visible de carga de tareas y progreso de objetivos |
| Banca abierta | **Descartada como vía principal** (no es instantánea). Pasa a V2 como conciliación |
| Negocio | Primero herramienta propia para su piso; comercializar es decisión posterior. Multi-grupo desde el día 1 |
| Auth | OTP de 6 dígitos por email (no enlace mágico: en iOS abre Safari y no la PWA) + Google |

## 4. Requisito clave: captura instantánea del gasto

El usuario exige que el gasto se registre **en el momento del cargo**; una notificación de un día después no sirve.

- Dispositivos: **Android**. Banco: **BBVA**, que avisa de las compras **solo por notificación de su app** (sin SMS ni email).
- iOS **no permite** leer notificaciones de otras apps (ni nativa ni PWA). Android sí, con "Acceso a notificaciones".
- **Vía elegida:** MacroDroid/Tasker lee la notificación de BBVA → `POST /api/capture/notification` con token personal → parseo → push "¿Categoría?" → hoja de un toque.
- **Formato real del aviso** (de la captura del historial interno de BBVA):
  - Título: `Pago aceptado 👍💳`
  - Texto: `Pago aceptado de 35,61 EUR en MERCADONA PUENTE ALCOCER con tu tarjeta terminada en 6267.`
  - Se parsea con **regex determinista**, sin IA. Gemini solo sugiere categoría y es respaldo. Los últimos 4 dígitos identifican la tarjeta y por tanto al pagador.
- **Tipos de aviso que le aparecen** (solo hay muestra de "Pago aceptado"; faltan las demás): Ingreso efectivo, Pago aceptado, Confirmar pago, Pago denegado, Abono de transferencia, Ingreso en tarjeta, Recibo de cargo, Retirada aceptada, Pago Bizum. Tratamiento propuesto en `AI_AND_CAPTURE.md` §13. Mientras no haya muestra, solo se registran "Pago aceptado".
- Modos de aviso por persona: **Aprendizaje** (avisa de cada gasto; por defecto al principio), **Solo si dudo** (comercios conocidos se guardan solos con "Deshacer"), **Nunca**.
- Por verificar en móvil real: que el aviso push del sistema Android traiga el mismo texto que el historial interno de BBVA, que el contenido se lea con la pantalla bloqueada, y que MacroDroid no sea cerrado por el ahorro de batería. El usuario dijo "si se leen las notificaciones" pero no quedó claro si completó la prueba con MacroDroid.

## 5. Estado del repositorio

Hecho y probado:
- `supabase/migrations/` (3 archivos): perfiles, espacios (personal/grupo), membresías, invitaciones (solo hash del token), auditoría append-only; RLS deny-by-default; RPC `create_group`, `update_group`, `create_invitation`, `revoke_invitation`, `preview_invitation`, `accept_invitation`, `leave_group`, `set_member_role`, `remove_member`; alta de usuario crea perfil + espacio personal.
- `supabase/tests/`: **115 aserciones pgTAP** que pasan. Se comprobó que detectan fallos rompiendo a propósito dos protecciones en una copia.
- `supabase/tests/run-local.sh`: ejecuta migraciones + tests en un PostgreSQL 16 desechable con una capa que imita `auth` de Supabase (`shim/auth_shim.sql`). Necesita `postgresql-16` y `postgresql-16-pgtap`.
- `.github/workflows/ci.yml`: escrita, **nunca ejecutada**.

No hecho:
- App Next.js, PWA, login OTP, pantallas, design tokens (usar el prototipo v2).
- Parser de avisos BBVA y endpoint de captura.
- Despliegue en el NAS.
- Integración con Gemini.

**Limitación del entorno anterior:** Docker no arrancaba, por eso se probó con un Postgres normal más un shim. En local conviene **validar contra Supabase real** (`supabase start` + `supabase test db`) y confirmar que triggers sobre `auth.users`, privilegios por defecto y funciones se comportan igual.

## 6. Plan de fases acordado

| Fase | Contenido |
|---|---|
| 0 | Cimientos: repo, CI, auth, modelo base + RLS + tests (BD hecha; falta app y despliegue) |
| 1 | Grupos e invitaciones en la UI; participantes sin cuenta (`memberships.user_id` nulo + reclamar) |
| 2 | Compra compartida en tiempo real, modo tienda |
| 3 | Gastos: reparto entre N, saldos, liquidación, "por revisar", memoria de comercio; visibilidad Privado / Algunas personas / Todo el grupo; plantillas de reparto por categoría |
| 4 | Tareas del hogar con recurrencia simple y carga visible |
| 5 | Asistente (texto/voz/foto) + **captura por notificación de BBVA** + push |
| 6 | Pantalla "Hoy" y pulido; agenda con ICS |

Spikes: S1 captura con Gemini sobre 30-50 frases/tickets reales; S2 PWA en móviles reales (login OTP instalada, audio, push); S3 captura instantánea Android+BBVA.

## 7. Infraestructura del usuario

- NAS UGREEN (UGOS Pro). Panel local: `http://192.168.1.67:9999/desktop/`. Acceso remoto del panel: `https://ug.link/silver-nas`.
- URL pública del NAS (Tailscale + Caddy): `https://nas.tailf79b60.ts.net`. Verificado desde internet: devuelve una página de prueba "NAS online" servida por Caddy.
- **Modelo del NAS y RAM: desconocidos** (se le preguntó varias veces). Supabase autoalojado necesita varios contenedores.
- Propuesta de despliegue: Docker Compose en la app de Docker de UGOS con (a) Supabase, (b) la app Next.js, (c) rutas en Caddy. **No exponer** Postgres ni Studio. La PWA exige HTTPS. Si se publica Supabase por el mismo dominio, valorar un puerto distinto con Funnel o un prefijo de ruta; revisar `API_EXTERNAL_URL` y las URLs de redirección de Auth.
- Responsabilidades que asume el usuario al autoalojar: copias de seguridad fuera del NAS, actualizaciones, caídas de luz o internet.

## 8. Seguridad y cumplimiento (puntos que no deben perderse)

- **Rotar la clave de Gemini** pegada en el chat. Debe vivir solo en variables de entorno del servidor, con límite de gasto. Usar acceso de pago (la capa gratuita puede usar los datos para mejorar productos; verificar términos vigentes).
- A Gemini solo se envía lo mínimo: la captura, nombres de categorías y de miembros. Nunca historial, saldos, IBAN ni datos privados de otros.
- Los avisos bancarios y los tickets son **datos no confiables** (riesgo de prompt injection).
- Ingresos y cuentas son privados por defecto. Ningún owner/admin ve lo privado de otro miembro.
- Token de captura por usuario y dispositivo, guardado como hash, revocable, con un único permiso: crear gastos "por revisar" propios.
- RGPD: para su piso con consentimiento no hay problema; si abre el producto a terceros pasa a ser responsable del tratamiento (política de privacidad, DPA con subencargados, etc.).
- Aviso no legal: revisar su contrato laboral (exclusividad, concurrencia, propiedad intelectual) antes de comercializar.

## 9. Diseño

Prototipo vigente: `docs/design/mockup-v2.html` (un móvil navegable con Hoy, Dinero, Compra, Más, hoja de añadir con parseo en vivo y simulación del aviso de BBVA con comercio conocido y nuevo).
- Oscuro primero, lienzo petróleo, acento menta, melocotón para avisos, tres colores de miembro; Sora (cifras/titulares) + Manrope (texto).
- Cristal solo en la capa flotante (barra inferior, hojas, avisos); contenido sobre superficies sólidas.
- Anillo por categorías, barras diarias, números que cuentan, hojas con resorte, vibración en Android.
- Fuentes de inspiración consultadas: Copilot Money, normas de Apple sobre materiales (Liquid Glass), guías de tendencias fintech 2026.
- **El usuario aún no ha dado su opinión sobre el v2.** Es el primer pendiente.

## 10. Pendientes del usuario

1. Revocar la clave de Gemini y crear otra con facturación y límite.
2. Modelo y RAM del NAS; si tiene dominio propio (hoy usa el `ts.net`); dónde harán copias de seguridad.
3. Una captura de cada tipo de aviso de BBVA que falta (con dígitos de tarjeta tapados).
4. Su opinión sobre el prototipo v2.
5. Confirmar si su hermana y su compañera de piso usan Android y qué banco tiene cada una.
6. Resultado de la prueba de MacroDroid.

## 11. Siguientes pasos técnicos propuestos

1. Clonar, leer este documento y ejecutar `supabase/tests/run-local.sh`. Después repetir los tests contra un Supabase local real (`supabase init`, `supabase start`, `supabase test db`) y corregir lo que diverja.
2. Crear el esqueleto Next.js + Tailwind + shadcn/ui + PWA con los tokens del mockup v2, tipos generados de la BD y cliente Supabase.
3. Login por OTP + Google, y pantallas: crear grupo, invitar (enlace), vista previa, unirse, selector de contexto, miembros. Tests e2e con Playwright en viewport móvil.
4. Preparar los archivos de despliegue para el NAS (compose de Supabase, compose de la app, rutas de Caddy, script de migraciones) y verificarlos en un entorno local antes de que el usuario los aplique.
5. Seguir con las fases 1 a 6.

## 12. Prompt sugerido para arrancar en local

> Lee `docs/HANDOFF.md` y después `docs/PHASE_0.md`, `docs/adr/*` y `docs/AI_AND_CAPTURE.md`. Estamos en la Fase 0. Primero ejecuta los tests de base de datos y repítelos contra un Supabase local real. Después construye el esqueleto de la app Next.js según el ADR-001 y el prototipo `docs/design/mockup-v2.html`. Trabaja por fases con criterios de aceptación y revisa tu propio código antes de seguir. No crees Pull Requests. Habla en español y sé crítico con mis decisiones.
