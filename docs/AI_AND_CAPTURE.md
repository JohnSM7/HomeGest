# IA y captura de gastos (especificación para revisión)

> Complementa `PRODUCT_DISCOVERY.md` §12 y `adr/ADR-001-stack.md`. Estado: propuesta.

## 1. Qué usa IA (Gemini) y qué no

Regla: **la IA interpreta lenguaje, imágenes y audio. Todo lo numérico y todo permiso es código determinista.**

| # | Característica | Usa Gemini | Fase | Detalle |
|---|---|---|---|---|
| 1 | Gasto por texto o voz ("Compré 35 de gasolina") | Sí | 4 | Audio/texto → JSON estructurado |
| 2 | Gasto por foto de ticket | Sí (visión) | 4 | Comercio, fecha, total, líneas opcionales |
| 3 | Sugerir categoría cuando no hay regla | Sí | 4 | Solo si ninguna regla del hogar acierta |
| 4 | Limpiar el nombre del comercio ("COMPRA TARJ *1234 MERCADONA 0021" → Mercadona) | Reglas primero, Gemini si falla | 4 | |
| 5 | Preguntas en lenguaje natural ("¿cuánto en restaurantes?") | Sí, solo para elegir la consulta | 4 | El modelo no calcula; llama a consultas tipadas y redacta el resultado |
| 6 | Crear tareas, eventos, recordatorios por frase | Sí | 4 | Siempre con tarjeta de confirmación |
| 7 | Añadir varios productos a la compra por voz ("leche, huevos y café") | Sí | 4 | Separa y normaliza productos |
| 8 | Documentos: extraer emisor, fecha, importe, vencimiento, garantía | Sí (visión/PDF) | MVP 2 | |
| 9 | Resumen mensual del piso en lenguaje natural | Sí (solo redacción) | MVP 2 | Las cifras vienen de SQL |
| 10 | Sugerencias de compra ("el café se acaba cada 12 días") | No: estadística simple | V2 | |

**No usan IA:** saldos, reparto entre miembros, sumas, recurrencias, permisos, detección de duplicados, envío de notificaciones, reglas aprendidas.

## 2. Flujo "registrar gasto"

Cuatro entradas, un mismo embudo:

```
Entrada: texto | voz | foto de ticket | atajo de Apple Pay (§4) | (futuro) banca
        │
  1. Normalizar        → texto limpio, importe en céntimos, fecha, comercio probable
        │
  2. Reglas del hogar  → ¿comercio conocido? ¿palabra clave ("gasolina")? 
        │ sí → categoría + reparto por defecto de esa categoría (sin Gemini)
        │ no
  3. Gemini            → JSON con esquema estricto (ver §3). Solo si hace falta
        │
  4. Validación servidor (Zod + reglas): importe > 0, fecha razonable,
        categoría ∈ categorías del hogar, participantes ∈ miembros
        │
  5. Confianza + política
        ├─ alta  → guardar como CONFIRMADO + aviso silencioso con "Deshacer"
        └─ baja  → guardar como POR REVISAR + notificación para categorizar (§4)
        │
  6. Reparto: plantilla de la categoría (alquiler: cuotas; compra: a partes iguales)
        │
  7. Aprendizaje: si el usuario corrige/elige categoría → regla Comercio→Categoría
        (se pregunta una vez: "¿Aplicar siempre a este comercio?")
```

Estados: `borrador → por_revisar → confirmado → anulado`. Cada captura lleva `client_request_id` para evitar duplicados por reintentos.

### Confianza (no se fía de la "autoevaluación" del modelo)
Puntuación calculada por el servidor a partir de: regla de comercio existente (+), comercio visto antes con la misma categoría (+), importe y fecha extraídos sin ambigüedad (+), categoría propuesta solo por el modelo (−), ticket borroso o total no coincide con la suma de líneas (−). Umbrales empiezan conservadores y se ajustan con datos reales.

### Qué se envía a Gemini
Solo: el texto/audio/imagen de la captura, la lista de **nombres de categorías** del hogar y los **nombres de los miembros**. Nunca historial de gastos, saldos, IBAN, datos de otros miembros ni privados de otros. El contenido del ticket se trata como **dato no confiable** (no puede dar órdenes al modelo ni activar herramientas).

## 3. Contrato de salida de Gemini (esquema)

```json
{
  "intent": "expense",
  "amount_minor": 3500,
  "currency": "EUR",
  "date": "2026-10-04",
  "merchant": "string | null",
  "category": "id de la lista recibida | null",
  "category_candidates": ["id", "id", "id"],
  "description": "string | null",
  "payer_hint": "nombre de miembro | null",
  "participants_hint": ["nombres"] ,
  "missing": ["campos que no pudo determinar"]
}
```

El servidor valida el JSON; si no cumple el esquema se descarta y se pide la captura manual (la app nunca se queda bloqueada por la IA).

## 4. Notificación "¿En qué categoría?"

### Qué es posible y qué no
La app **solo puede avisar de un gasto si se entera de que ocurrió**. Una PWA no puede leer SMS, notificaciones bancarias ni movimientos de tarjeta. Las vías reales:

| Vía | Cobertura | Fase | Estado |
|---|---|---|---|
| **Atajo de iOS "Transacción"** (automatización de Wallet) | Pagos con Apple Pay con tarjeta añadida a Wallet: importe, comercio y tarjeta | 4 | **A validar en spike S2**: disponibilidad exacta de campos y ejecución automática sin pedir permiso cada vez |
| Android | No hay equivalente oficial en Google Wallet. Posible con apps tipo Tasker/MacroDroid que reenvían la notificación del banco a nuestro endpoint | 4 (opcional) | Frágil, depende del banco |
| **Banca abierta** (PSD2) | Todas las tarjetas y cuentas, incluidos pagos online y recibos | MVP 2 | Aplazada |
| Manual / voz / foto | Todo | 2 y 4 | Siempre disponible |

Limitaciones: no cubre pagos online con tarjeta en la web, Bizum, domiciliaciones ni efectivo. Para esos, voz/foto ahora y banca después.

### Secuencia
```
Pago con Apple Pay
  → iOS dispara el Atajo → POST /api/capture/wallet  (token personal, ver seguridad)
  → Servidor: crea gasto "por revisar" con importe + comercio (+ sugerencia)
  → Web Push solo al PAGADOR:  "43,20 € en MERCADONA · ¿Categoría?"
  → Tocar abre la hoja "Revisar" (un toque):
        [Supermercado] [Restaurantes] [Otro…]      ← 3 sugerencias, la 1ª preseleccionada
        Descripción (opcional): ______  🎤
        Reparto: a partes iguales entre 3 ▾        Visible: Todo el piso ▾
        [Confirmar]
  → Regla aprendida (si procede) y gasto "confirmado"
```

### Detalles
- **Botones en la propia notificación:** Android (Chrome) permite acciones; **iOS no** muestra botones en notificaciones web. Por eso el diseño base es *tocar → hoja de un toque*, y las acciones en la notificación son un extra en Android.
- **Descripción:** campo opcional, por texto o voz (Gemini la limpia). Para comercios conocidos no se pide.
- **Privacidad en pantalla de bloqueo:** ajuste "Ocultar importe y comercio" (texto genérico: "Nuevo gasto por categorizar").
- **Quién recibe el aviso:** solo quien hizo el pago. Los demás ven el gasto cuando se confirma y solo si la visibilidad lo permite.
- **Si no respondes:** el gasto queda en "Por revisar" (contador en Hoy). Un único recordatorio al final del día, no uno por gasto.
- **Resumen de avisos:** máximo N notificaciones al día; el resto se agrupa ("4 gastos por categorizar").

### "Cada vez que se realice un gasto" — recomendación
Preguntar **siempre** da fatiga en 2 semanas. Propongo un ajuste por persona:

| Modo | Comportamiento |
|---|---|
| **Aprendizaje** (por defecto las primeras semanas) | Avisa de cada gasto detectado |
| **Solo si dudo** (recomendado después) | Comercios con regla → se guardan solos con aviso silencioso y "Deshacer"; desconocidos → te pregunta |
| **Nunca** | Todo va a "Por revisar" sin avisos |

## 5. Seguridad del endpoint de captura (atajos)

- Token **por usuario y por dispositivo**, generado en Ajustes, mostrado una vez, guardado como hash, revocable.
- Alcance único: **crear gastos "por revisar"** propios. No lee datos ni confirma nada.
- Límite de frecuencia y tamaño; idempotencia por `client_request_id`.
- El token no da acceso al resto de la app.

## 6. Coste y control

- Con reglas del hogar acertando, un gasto cuesta **0 llamadas** a Gemini.
- Contador de llamadas y coste por hogar; tope mensual configurable; si se supera, la app sigue funcionando en modo manual.
- Modelo ligero para texto/categoría, uno mayor solo para tickets difíciles. Versiones concretas se fijan en el spike S1.

## 7. Evaluación (antes de dar por buena la IA)

- Conjunto de prueba con 30–50 frases y tickets reales en español (aportados por ti, anonimizados).
- Objetivos iniciales: importe correcto ≥ 95 %, fecha ≥ 95 %, categoría correcta en primera sugerencia ≥ 75 % con reglas vacías, y ≥ 90 % tras 2 semanas de uso.
- Se reevalúa en cada cambio de modelo o de prompt.

## 8. Más vías de detección y banca abierta (añadido 2026-10-04)

### Vías sin banca abierta, por orden de esfuerzo
| Vía | Cómo funciona | Cubre | Plataforma | A validar |
|---|---|---|---|---|
| Atajo Apple Pay | Automatización "Transacción" de Wallet → endpoint | Pagos con Apple Pay | iOS | Campos entregados y ejecución sin confirmación |
| **SMS del banco** | Automatización "Mensaje" de Atajos (filtra por remitente del banco) reenvía el texto al endpoint | Cualquier tarjeta con aviso por SMS | iOS (Atajos); Android (Tasker/MacroDroid) | Que el banco envíe SMS por cada compra y que iOS lo ejecute sin preguntar |
| **Email del banco** | Regla de reenvío a una dirección personal de entrada (`tu-codigo@…`) | Cualquier banco que avise por email | Cualquiera | Servicio de correo entrante y formato de los avisos |
| Banca abierta | Conexión autorizada con el banco | Todo | Cualquiera | Coste, cobertura, consentimiento |

El texto de SMS o email se interpreta con Gemini (importe, comercio, últimos 4 dígitos, fecha). Los datos estructurados de Wallet no necesitan IA.

**Duplicados entre vías:** si llegan el aviso de Wallet y el SMS del mismo pago, se fusionan por regla (mismo usuario, mismo importe, ventana de unos 10 minutos).

### Banca abierta (open banking, PSD2)
- La normativa europea PSD2 obliga a los bancos a dar acceso a los datos de tus cuentas a terceros **si tú lo autorizas**, mediante interfaces seguras.
- Flujo: "Conectar banco" → eliges el banco → te redirige a **la web o app del propio banco** donde inicias sesión y apruebas → vuelves a HomeGest con un permiso de **solo lectura**. **La app nunca ve tu usuario ni tu contraseña.**
- Para ello hace falta un intermediario con licencia (agregador regulado, p. ej. Tink, TrueLayer, Enable Banking, GoCardless), porque HomeGest no tiene licencia propia.
- Limitaciones: el permiso caduca (hasta unos 180 días) y hay que reconectar; los movimientos llegan con retraso (de minutos a un día, según el banco); los nombres de comercio vienen sucios; cobran por conexión; contratar como empresa o autónomo es lo habitual. Algunos agregadores ofrecen modos gratuitos para uso propio: **verificar condiciones vigentes** en el spike.
- No puede mover dinero ni hacer pagos. Solo lee.
