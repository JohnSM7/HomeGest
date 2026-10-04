# Fase 0 — Cimientos (especificación para revisión)

> Actualización 2026-10-04 ([ADR-002](adr/ADR-002-groups.md)): donde dice "hogar" léase "grupo" (`spaces.type = 'group'`, con `group_kind` y `modules`). La invitación incluye enlace, código corto y QR. Los participantes sin cuenta pasan a la Fase 1.

> Sin código de producto todavía. Objetivo: una base segura, desplegada y probada sobre la que construir, y dos spikes que reducen el riesgo.

## 1. Qué vamos a construir

1. Repo Next.js + TypeScript + Tailwind + shadcn/ui, PWA instalable (manifest, iconos, service worker mínimo).
2. Proyecto Supabase (UE) enlazado, migraciones versionadas, entorno local reproducible.
3. Autenticación: **OTP por email** (código de 6 dígitos) y Google. Perfil automático al registrarse.
4. Modelo base y permisos:
   - `profiles`, `spaces` (`personal` | `household`), `memberships`, `invitations`, `audit_log`.
   - Al registrarse se crea el **espacio personal** automáticamente.
   - RPC: `create_household(name)`, `create_invitation(space, role)`, `accept_invitation(token)`, `leave_household(space)`.
   - Funciones helper: `is_member(space)`, `has_role(space, roles[])`.
   - **RLS en todas las tablas** + tests pgTAP de aislamiento.
5. Pantallas mínimas: login, crear hogar, invitar (compartir enlace/código), unirse, selector de contexto Personal ↔ Hogar, lista de miembros.
6. **Design tokens** (color, tipografía, espaciado, radio, sombra, modo claro/oscuro) y componentes base: botón, tarjeta, fila de lista, chip, hoja inferior, avatar de miembro, campo de captura, toast con "Deshacer", estado vacío.
7. CI (GitHub Actions): lint, typecheck, tests unitarios, tests pgTAP, comprobación "toda tabla del esquema `public` tiene RLS activa", build.
8. Documentación: README de arranque, este ADR, convenciones, checklist de seguridad.

## 2. Criterios de aceptación

| # | Criterio | Cómo se verifica |
|---|---|---|
| A1 | Registro y login por OTP y Google funcionan **en el móvil con la PWA instalada** (iOS y/o Android) | Prueba manual + e2e |
| A2 | Al registrarse existe exactamente un espacio personal | pgTAP |
| A3 | Crear un hogar convierte al creador en `owner` | pgTAP |
| A4 | Invitación: token aleatorio, guardado como hash, caduca (7 días), uso único; reutilizarla o usarla caducada falla | pgTAP + e2e |
| A5 | Un usuario del hogar X **no puede leer, insertar, actualizar ni borrar** nada del hogar Y, en ninguna tabla | pgTAP (suite que recorre todas las tablas) |
| A6 | Un miembro no ve el espacio personal de otro; ni un `owner` ve lo privado de otro miembro | pgTAP |
| A7 | Salir de un hogar revoca el acceso inmediatamente | pgTAP |
| A8 | `audit_log` registra creación de hogar, invitaciones, altas/bajas de miembros y cambios de rol; es append-only (nadie puede editar o borrar) | pgTAP |
| A9 | La CI falla si se crea una tabla sin RLS | CI |
| A10 | Migraciones aplican desde cero y es reproducible el entorno local | CI |
| A11 | La PWA es instalable y la app carga en < 2 s con red 4G simulada (shell) | Lighthouse |
| A12 | Ninguna clave secreta (service role, Gemini) llega al cliente | Revisión + escaneo de secretos en CI |

## 3. Spikes (se ejecutan en paralelo, resultado = decisión documentada)

**S1 — Captura con Gemini (1–2 días).** Con 30–50 frases y tickets reales en español: ¿precisión de importe, fecha, comercio y categoría? ¿latencia? ¿coste por captura? Resultado: elección de modelo y umbrales de confianza iniciales.
**S2 — PWA en iOS/Android reales (1 día).** Login OTP dentro de la PWA instalada; grabación de audio con `MediaRecorder` y su envío a Gemini; foto desde cámara; Web Push. Resultado: lista de limitaciones confirmadas y soluciones.
**S3 — Banca abierta (adelantado, 2026-10-04):** requisito de funcionar igual en Android e iOS. Conectar tu cuenta con un agregador en modo propio, medir latencia, calidad de los nombres de comercio y cobertura; comprobar si se pueden vincular cuentas de las otras dos personas. Ver `AI_AND_CAPTURE.md` §9.

## 4. Fuera de alcance de la Fase 0

Gastos, compra, tareas, calendario, IA en producto, documentos, banca, notificaciones de negocio, widgets.

## 5. Siguientes fases adaptadas a un piso de 3 (propuesta de orden)

Reordeno para tener valor real en tu casa cuanto antes (ya tenéis Google Calendar; el dolor está en gastos y compra):

| Fase | Contenido | Por qué en este orden |
|---|---|---|
| 1 | Compra compartida en tiempo real | Más simple, uso diario, hace que los otros dos entren |
| 2 | Gastos: reparto entre 3, saldos, liquidación, "por revisar" | Dolor principal de un piso |
| 3 | Tareas del hogar (rotación simple) y carga visible | Limpieza, basura, suministros |
| 4 | Asistente: captura texto/voz/foto + consultas | Diferenciador, necesita datos de 1–3 |
| 5 | Pantalla "Hoy" + pulido visual + notificaciones | Se afina con uso real |
| 6 | Agenda interna + ICS | Menos urgente para vosotros |

**Ajuste de permisos por vuestro caso:** con una compañera que no es familia, el reparto de gastos y la privacidad pesan más. Por eso, desde la Fase 2 los gastos admitirán **Privado / Todo el piso / Solo algunas personas**, y los repartos tendrán **plantillas por categoría** (alquiler con cuotas distintas, suministros a partes iguales, compra a partes iguales, regalo solo entre hermanos).

## 6. Riesgos de esta fase

- Políticas RLS incorrectas → mitigación: tests exhaustivos y revisión adversarial antes de cerrar.
- Fricción de login en iOS → OTP, no enlace.
- Exceso de tiempo en diseño visual → tokens y 7–8 componentes; el pulido llega con la Fase 5.

## 7. Qué necesito para empezar

1. Un proyecto Supabase en región UE (puedes crearlo tú, o dime si lo creo yo con la integración disponible; **puede tener coste según tu organización**, por eso te lo pregunto).
2. Una clave de Gemini con facturación activa y límite de gasto mensual (lo gestionas tú; no me la pegues en el chat, se pondrá en variables de entorno).
3. Tu validación del orden de fases (§5) y del ADR-001.
