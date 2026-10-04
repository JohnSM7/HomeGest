# ADR-002 — Grupos libres en lugar de "hogar"

- Estado: **Propuesto**
- Fecha: 2026-10-04
- Origen: el producto no debe centrarse en un piso compartido; el usuario quiere crear grupos a su gusto y añadir a otras personas.

## Decisión

1. **La unidad del producto es el Grupo** (en el código, `spaces` con `type = 'group'`). "Hogar" pasa a ser solo una plantilla.
2. Cada usuario tiene su **espacio personal** y puede pertenecer a **tantos grupos como quiera**.
3. Al crear un grupo se elige una **plantilla opcional** (`group_kind`): `home`, `couple`, `family`, `trip`, `event`, `work`, `other`. La plantilla solo fija valores por defecto (módulos activos, categorías iniciales, plantillas de reparto). No cambia el modelo ni los permisos.
4. **Módulos activables por grupo** (`modules`): Gastos, Compra, Tareas, Agenda y, más adelante, Documentos y Activos. Un grupo de viaje solo necesita Gastos y Compra.
5. **Cómo se añade gente** (no hay buscador de usuarios, para no permitir enumerar cuentas):
   - Enlace de invitación (token aleatorio, hash en BD, caducidad, usos máximos, rol).
   - Código corto de 8 caracteres y QR para hacerlo en persona.
   - Invitación por email (envía el enlace).
6. **Participantes sin cuenta** (`memberships.user_id` nulo con nombre visible): permiten repartir gastos con alguien que aún no usa la app. Cuando esa persona entra por un enlace, puede **reclamar** su identidad y hereda el historial. Fase 1.
7. **Saldos por grupo.** No se compensan deudas entre grupos distintos.
8. **Hoy** agrega todos los grupos con el selector de contexto "Todo / Personal / cada grupo".
9. **Grupos cerrables** (viajes, eventos): se liquidan saldos y se archivan en solo lectura.
10. Un registro pertenece a **un único espacio**. Pasar un gasto personal a un grupo es una acción explícita ("Mover a…") que cambia su `space_id` y su visibilidad, nunca automática.

## Cosas que no cambian
Privacidad por registro (privado / algunas personas / todo el grupo), RLS en BD, roles `owner/admin/member/limited`, auditoría. Los permisos ya estaban diseñados por espacio, no por "familia".

## Riesgos
- **Genericidad:** un "grupo para todo" se parece a Splitwise más Notion. Mitigación: plantillas con buenos valores por defecto, captura por IA y módulos activables, no una pantalla vacía.
- **Más combinaciones que probar** en permisos: la suite de aislamiento debe cubrir usuarios en varios grupos.
- **Límites de plan** (número de grupos, miembros) quedan para la monetización.
