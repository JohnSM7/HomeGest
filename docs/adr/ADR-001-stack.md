# ADR-001 — Stack técnico y plataforma

- Estado: **Propuesto** (pendiente de tu aprobación)
- Fecha: 2026-10-03
- Contexto: desarrollador en solitario (tiempo parcial), primer hogar = piso de 3 personas (usuario, hermana, compañera), mercado España/EUR, IA con Gemini, hosting de datos con Supabase.

## Decisión

| Capa | Elección | Notas |
|---|---|---|
| Plataforma | **PWA móvil-first** (instalable en pantalla de inicio) | Sin app nativa. Un solo código para móvil y escritorio |
| Frontend | **Next.js (App Router) + TypeScript estricto + Tailwind + shadcn/ui** | UI densa y pulida con poco código |
| Repo | **Un solo repo, una sola app** (sin Turborepo) | Módulos por dominio dentro de `src/modules`. Monorepo solo si aparece una segunda app |
| Backend de datos | **Supabase**: Postgres + Auth + Storage + Realtime | Región UE. Es Postgres estándar, portable |
| Lógica de negocio | **Funciones SQL (RPC) para operaciones atómicas** (crear hogar, aceptar invitación, crear gasto con reparto) + **Server Actions / Route Handlers** de Next.js para IA y orquestación | Permisos siempre en BD |
| Permisos | **Row Level Security** + funciones helper `SECURITY DEFINER` + tests pgTAP | Ver `PRODUCT_DISCOVERY.md` §9 |
| IA | **Gemini**, solo desde servidor, tras un módulo `lib/ai` propio | Texto, audio e imagen con el mismo modelo (ver abajo) |
| Migraciones | **Supabase CLI** (`supabase/migrations/*.sql`), revisadas en PR | Nada de cambios de esquema desde el panel |
| Tests | Vitest (dominio), pgTAP (RLS), Playwright (e2e en viewport móvil) | |
| Hosting web | Vercel (región UE) o equivalente | Plan Hobby es no comercial; pasar a Pro si se comercializa |
| Notificaciones | Web Push (VAPID) + email transaccional | iOS: solo con la PWA instalada |

## Por qué PWA y no app nativa (y qué se pierde)

Para un único desarrollador y un hogar de 3, la PWA es la decisión correcta: despliegue instantáneo, sin tiendas, un solo código. Limitaciones conocidas que condicionan el diseño:

1. **Login en iOS:** un *magic link* abre Safari y no la PWA instalada (almacenamiento separado). → Usar **código OTP de 6 dígitos por email** (y Google OAuth), no enlaces.
2. **Push en iOS:** solo funciona con la PWA añadida a la pantalla de inicio y con permiso concedido tras un gesto. Funciona, pero hay que guiar la instalación en el onboarding.
3. **Voz:** no depender de la Web Speech API (inconsistente en iOS). → Grabar audio con `MediaRecorder` y enviarlo a Gemini (entiende audio nativo). *Validar formato en iOS en el spike S2.*
4. **Foto de ticket:** `<input type="file" accept="image/*" capture>` es suficiente.
5. **Sin widgets ni accesos en pantalla de bloqueo.** Mitigación barata: **Atajos de iOS** con "Obtener contenido de URL" que dicta una frase y la envía a un endpoint de captura con un token personal de alcance limitado (solo crear borradores). Se evalúa en la fase del asistente.
6. **Offline:** shell cacheado + cola de escrituras en IndexedDB solo para capturas (compra, gasto, tarea). Sin sincronización bidireccional compleja.

Si más adelante la PWA se queda corta, la capa de datos (Supabase + RPC) sirve igual a una app Expo: el coste de migrar es solo la UI.

## IA con Gemini

- Un solo modelo cubre **STT + OCR de tickets + extracción estructurada**, lo que simplifica mucho frente a encadenar servicios.
- Salida con **esquema JSON estricto** validado en servidor (Zod); el modelo nunca escribe en BD directamente (propuesta → confirmación → ejecución).
- Modelo ligero para la ruta frecuente (captura/categorización) y uno mayor solo para conversación compleja o tickets difíciles. *Los nombres/versiones de modelo se fijan en la Fase 5 tras medir precisión y coste.*
- **Privacidad de datos:** usar un acceso **de pago** (Gemini API con facturación activa, o Vertex AI en región UE). La capa gratuita puede usar los datos enviados para mejorar productos. *Verificar los términos vigentes antes de enviar datos reales.* Recomendación: empezar con Gemini API de pago (simple) y pasar a Vertex AI UE antes de abrir el producto a terceros.
- Minimización: no enviar IBAN, DNI ni datos innecesarios; contexto mínimo por petición; sin volcados de BD.
- La API key vive solo en variables de entorno del servidor. Nunca en el cliente.
- Límite de gasto mensual configurado en Google Cloud + contador de coste por hogar en nuestra BD.

## Dinero y reparto

- Importes en **enteros de céntimos** + moneda (`amount_minor bigint`, `currency 'EUR'`). Nunca `float`.
- Reparto por método del **resto mayor** (la suma de partes siempre es igual al total), con tests de propiedades.

## Consecuencias

- (+) Un solo código, despliegue en minutos, coste casi nulo en MVP.
- (+) Seguridad real en BD y no solo en la aplicación.
- (−) Dependencia de las limitaciones de PWA en iOS (mitigadas arriba).
- (−) Dependencia de Supabase y Gemini (se aíslan tras `lib/ai` y la capa de datos).

## Alternativas descartadas

- Expo/React Native: más capacidades nativas, pero doble UI y tiendas para un equipo de una persona.
- Backend propio (NestJS) desde el día 1: más código a mantener sin aportar valor en MVP.
- Firebase: permisos relacionales complejos y consultas agregadas peor encajadas que en Postgres.
