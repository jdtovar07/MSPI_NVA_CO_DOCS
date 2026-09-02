# ms_audit — Mantenimiento

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Fecha del documento | 2026-08-18 |
| Alcance | Lineamientos de mantenimiento del repositorio `ms_audit` (documental) y de la funcionalidad de auditoría que deberá heredar/migrar desde `ms_iam`, con base en `docs/MIGRATION-NOTES.md` |

---

## 1. Gestión de versiones

No hay `CHANGELOG.md` ni versionamiento semántico propio de `ms_audit`. El único indicador de versión es `docs/openapi.yaml` → `info.version: 0.0.0`, valor consistente con un contrato que aún no ha tenido ninguna entrega funcional (a diferencia de, por ejemplo, `ms_iam/docs/openapi.yaml`, cuyo `info.version` está en `2.0.0`). Se recomienda que, cuando se inicie la implementación real, `ms_audit` adopte SemVer desde `0.1.0` para su primera versión funcional y sincronice ese número con `info.version` del OpenAPI, replicando la práctica ya sugerida para `ms_iam`.

## 2. Mantenimiento del repositorio documental (lo único mantenible hoy)

Dado que `ms_audit` es hoy un conjunto de documentos, su "mantenimiento" consiste en mantenerlos sincronizados con la realidad de `ms_iam`, que es donde vive la implementación activa. Riesgos concretos de desactualización detectados:

- **`docs/MIGRATION-NOTES.md` depende de la estabilidad del contrato de `ms_iam`.** Si `ms_iam` cambia el esquema de `AuditEventRequest`, añade campos obligatorios, o modifica el comportamiento de error (`401` vs `503`), este documento y `docs/openapi.yaml` de `ms_audit` quedarían desactualizados silenciosamente, ya que no hay ninguna prueba de contrato automatizada (ver `05-Pruebas.md`) que detecte la divergencia.
- **El catálogo de `eventType` documentado está incompleto respecto al MER.** `MIGRATION-NOTES.md` sección 4 solo documenta `ASSESSMENT_PUBLISHED` y `ENTITY_ORDER_TYPE_CHANGED` como eventos emitidos "hoy" por `ms_assessment`, mientras que `docs/proyecto/DB-MER.txt` lista además `ASSESSMENT_CREATED`, `ASSESSMENT_CLONED`, `STEWARD_PROPAGATED` e `INVENTORY_DELIVERY_UPDATED` como parte del catálogo previsto. Si se implementan nuevos productores de estos eventos en `ms_assessment` sin actualizar `MIGRATION-NOTES.md`, la documentación de `ms_audit` quedará incompleta respecto al tráfico real que debería migrar.
- **El README de `ms_audit` asume una relación `ms_admin` → consumidor futuro** que no tiene ninguna referencia de código verificada en `ms_admin` (ver `01-Planificacion.md`, sección 9). Si esa relación deja de ser válida (por ejemplo, si `ms_reporting` termina siendo el consumidor real en vez de `ms_admin`), el README quedaría desalineado con el diseño real del sistema.

## 3. Mantenimiento correctivo (heredado de la implementación real en ms_iam)

Puesto que la funcionalidad de auditoría vive hoy en `ms_iam`, cualquier incidente correctivo relacionado con auditoría debe atenderse allí, no en `ms_audit`. Puntos de fragilidad documentados y verificables:

- **Pérdida silenciosa de eventos de auditoría**: el patrón *best-effort* de `IamAuditGatewayAdapter` (ver `03-Diseno.md`, sección 5.2) implica que un fallo de red, un `INTERNAL_API_KEY` mal configurado, o un `ms_iam` caído, dejan operaciones de negocio en `ms_assessment` **sin traza de auditoría**, sin que ningún actor humano sea alertado activamente — solo queda un log `[AUDIT][IAM]` de nivel `warning`. `MIGRATION-NOTES.md` sección 5 ya identifica este riesgo y recomienda monitorizar ese patrón de log; no hay evidencia de que exista una alerta automatizada (Prometheus/Grafana u otro) configurada sobre esos logs específicos.
- **Ambigüedad 503 vs 401**: `ms_iam` responde `503` cuando `app.internal-api-key` no está configurada del lado servidor (en vez de rechazar con `401` por clave inválida). Un operador que solo mire el código HTTP podría interpretar `503` como caída del servicio en vez de como error de configuración, retrasando el diagnóstico. Vale la pena, para cuando exista `ms_audit`, distinguir estos dos casos con mensajes de error más explícitos, siguiendo el patrón de "mensajes de error auto-explicativos con el remedio" ya usado en otros manejadores de excepción de `ms_iam`.

## 4. Mantenimiento preventivo

- **No hay monitoreo ni alertas configuradas para el flujo de auditoría específicamente.** `ms_iam` expone métricas Prometheus vía Actuator (heredadas del stack general), pero no se encontró evidencia de un contador o dashboard específico para tasa de fallos de `POST /internal/audit/events`, que sería la métrica más relevante para detectar pérdida de eventos de auditoría antes de que se convierta en un problema de cumplimiento (dado que MSPI es, precisamente, un sistema orientado a ISO 27001).
- **Revisión periódica de la lista de `eventType` documentados vs. implementados**: se recomienda, como práctica preventiva, que cada vez que se añada un nuevo evento de auditoría en cualquier microservicio productor, se actualice simultáneamente `ms_audit/docs/MIGRATION-NOTES.md` sección 4, para que el inventario de eventos que deberá migrar `ms_audit` no quede desactualizado en el momento de implementarlo.
- **Vigilancia de la variable `INTERNAL_API_KEY`** en ambos extremos (`ms_assessment` y `ms_iam`) como parte de cualquier checklist de despliegue, dado que su desincronización produce fallos silenciosos de auditoría (best-effort) en vez de errores visibles de arranque.

## 5. Mantenimiento evolutivo — hoja de ruta ya documentada

A diferencia de la mayoría de microservicios del monorepo (que no tienen roadmap propio), `ms_audit` **sí tiene** una secuencia evolutiva explícita, documentada en `docs/MIGRATION-NOTES.md` sección 7 y resumida también en el README bajo "Evolución prevista":

| Paso | Descripción | Estado |
|---|---|---|
| 1 | Implementar ingesta equivalente en `ms_audit` (mismo contrato o v2) | No iniciado |
| 2 | Periodo de dual-write (`ms_assessment` → `ms_iam` y `ms_audit`) o *feature flag* | No iniciado |
| 3 | *Backfill* histórico desde `iam.audit_log` si el esquema destino difiere | No iniciado |
| 4 | Cambiar `MS_IAM_URL`/gateway por `MS_AUDIT_URL` en productores | No iniciado |
| 5 | Deprecar `POST /internal/audit/events` en `ms_iam` tras validación | No iniciado |

Adicionalmente, el README enumera funcionalidad evolutiva de negocio que iría más allá de la simple migración de la ingesta actual:

- API de **consulta** (`GET /audit/events`) con filtros por evaluación, actor, tipo de evento y rango de fechas — funcionalidad completamente nueva, sin precedente en `ms_iam`.
- API de **exportación** (`GET /audit/export`) — igualmente nueva.
- **Retención** de datos históricos — mencionada como objetivo de evolución, sin política ni mecanismo definido (ver `03-Diseno.md`, sección 6, para el riesgo de diseño asociado).
- **Separación de responsabilidades** respecto a `ms_iam`, motivación de negocio original para la existencia de `ms_audit` (ver `01-Planificacion.md`, objetivo 1).

## 6. Recomendación de priorización para el mantenimiento evolutivo

Dado que no hay cronograma, se enumera aquí una priorización razonada a partir de la evidencia recogida en este análisis, útil como insumo para quien retome el desarrollo de `ms_audit`:

1. **Cerrar la brecha de observabilidad del flujo actual** (sección 4) antes de iniciar la migración: sin métricas de fallo de ingesta, es difícil validar que el *dual-write* del paso 2 funciona correctamente una vez implementado.
2. **Implementar primero la ingesta (paso 1)** reutilizando el diseño ya validado en `ms_iam` (`InternalAuditApi` → `RecordAuditEventUseCase` → `AuditEventGateway`/adaptador JPA), dado que es el único flujo con precedente de código y menor riesgo de diseño.
3. **Diseñar la consulta (`GET /audit/events`) y su modelo de paginación/filtros** antes de exponerla, ya que es funcionalidad enteramente nueva sin diseño de datos de referencia más allá de los índices SQL ya existentes en `iam.audit_log` (que sí anticipan los filtros por `assessment_id`, `actor_user_id`, `event_type` y `entity_type`).
4. **Definir la política de retención** y el formato de exportación **antes** de implementar `ExportAuditLogUseCase`, para evitar rediseños posteriores del modelo de datos objetivo (p. ej., si se requiere particionamiento por fecha para soportar purgado eficiente).
5. **Ejecutar la migración de productores y depreciación del endpoint en `ms_iam`** (pasos 4 y 5) solo después de validar en un periodo de dual-write que no hay pérdida de eventos, dado que hoy el registro de auditoría ya es best-effort y una migración mal ejecutada podría agravar, no resolver, ese riesgo.
