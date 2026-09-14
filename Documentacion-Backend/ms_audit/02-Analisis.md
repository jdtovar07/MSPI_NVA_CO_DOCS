# ms_audit — Análisis

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Fecha del documento / Última revisión cruzada con código | **2026-10-19** |
| Estado | Activo |
| Alcance | Requerimientos funcionales/no funcionales, reglas de negocio y casos de uso de `ms_audit` |

---

## 1. Actores

| Actor | Tipo | Autenticación | Operaciones |
|---|---|---|---|
| AdminSistema | Humano | JWT Bearer (Keycloak realm `iam`) con rol `AdminSistema` | Listar eventos, consultar timeline de solicitud |
| `ms_iam` | Sistema | `X-Internal-Api-Key` | `POST /internal/audit/events` (login, password reset, etc.) |
| `ms_assessment` | Sistema | `X-Internal-Api-Key` | Eventos de evaluación, eliminación, ampliación |
| `ms_catalog` | Sistema | `X-Internal-Api-Key` | Eventos de eliminación de catálogo |

La autorización de consulta está fijada en código: `SecurityConfig` exige `.hasRole("AdminSistema")` en `/audit/**`. Las rutas `/internal/**` no usan JWT de usuario; solo la API key interna.

## 2. Requerimientos funcionales

| ID | Requerimiento | Evidencia en código |
|---|---|---|
| RF-01 | Registrar un evento de auditoría recibido por canal interno | `InternalAuditApi.record`, `RecordAuditEventUseCase` |
| RF-02 | Responder **202 Accepted** tras aceptar el evento | `InternalAuditApi`: `ResponseEntity.status(HttpStatus.ACCEPTED)` |
| RF-03 | Listar eventos con paginación y filtros (`page`, `size`, `q`, `eventType`, `entityType`, `dateFrom`, `dateTo`, `actor`, `requestNumber`) | `AuditApi.events`, `ListAuditEventsUseCase`, `AuditEventFilter` |
| RF-04 | Obtener trail de solicitud (cabecera + timeline) por `requestNumber` | `AuditApi.requestTrail`, `GetRequestAuditTrailUseCase` |
| RF-05 | Correlacionar eventos por `metadata_json.requestNumber` | `AuditLogRepository` (filtro `metadata_json ->> 'requestNumber'`), `AuditEventAdapter` |
| RF-06 | Resolver cabecera de solicitud en el microservicio dueño según prefijo | `RequestOwnerGatewayAdapter.findByRequestNumber` |

## 3. Requerimientos no funcionales

| ID | Requerimiento | Evidencia |
|---|---|---|
| RNF-01 | JWT stateless para `/audit/**` | `SecurityConfig` + OAuth2 Resource Server |
| RNF-02 | Comparación constant-time de API key interna | `InternalApiKeyFilter`: `MessageDigest.isEqual` |
| RNF-03 | Sin DDL automático | `application.yaml`: `sql.init.mode: never`, `ddl-auto: none` |
| RNF-04 | Arranque fallido sin `DB_CREDENTIAL` | `DBCredentialConfig` |
| RNF-05 | Trazabilidad HTTP vía `X-Trace-Id` | `TraceIdFilter`, `GlobalExceptionHandler` |
| RNF-06 | Actuator health/info públicos | `SecurityConfig` `permitAll` en `/actuator/health`, `/actuator/info` |
| RNF-07 | Append-only: no soft-delete de `audit_log` | Modelo de tabla en `patch-audit-schema.sql` (sin columna `deleted_at`) |

## 4. Reglas de negocio

### 4.1 Ingestión (`RecordAuditEventUseCase` / `InternalAuditApi`)

1. El cuerpo `AuditEventRequest` se mapea a `AuditEvent` (eventType, entityType, entityId, assessmentId, actorUserId, occurredAt, ip, userAgent, before/after/metadata JSON).
2. Persistencia en `audit.audit_log`; la correlación con solicitudes de negocio se espera en `metadata_json.requestNumber` cuando aplique.
3. Respuesta HTTP **202** con payload de éxito `"recorded"` (vía `ApiResponseMapper`).

### 4.2 Listado (`ListAuditEventsUseCase`)

Filtros opcionales combinados en consulta JPA/nativa sobre `audit.audit_log`, incluyendo igualdad de `metadata_json ->> 'requestNumber'` cuando se envía `requestNumber`. Paginación con `page` (default 0) y `size` (default 20).

### 4.3 Trail de solicitud (`GetRequestAuditTrailUseCase`)

1. Obtiene cabecera vía `RequestOwnerGateway` (implementación `RequestOwnerGatewayAdapter`).
2. Enrutado por prefijo del número:
   - `SOL-CAT-` → `ms_catalog`
   - `SOL-PWD-` → `ms_iam`
   - `SOL-ELIM-` / `SOL-AMPL-` → `ms_assessment`
   - Otros: intenta assessment → catalog → iam
3. Timeline: eventos locales ordenados por `requestNumber` en metadata (`findEventsByRequestNumberAsc`).

### 4.4 Tipos de evento observados (productores)

Familias reportadas/observadas en integraciones: `AUTH_LOGIN_*`, `PASSWORD_RESET_*`, `DELETION_*`, `EXTENSION_*`, `CATALOG_DELETION_*`, `ASSESSMENT_*`. El microservicio no enumera un catálogo cerrado de tipos en el dominio; acepta el string `eventType` del productor.

## 5. Casos de uso (resumen operativo)

| Caso de uso | Actor | Precondición | Resultado |
|---|---|---|---|
| Registrar evento | Productor S2S | API key válida | 202, fila en `audit.audit_log` |
| Listar eventos | AdminSistema | JWT + rol | 200 paginado |
| Trail de solicitud | AdminSistema | JWT + rol; solicitud resoluble o solo eventos locales | 200 con header + timeline |

## 6. Productores y consumidores

| Servicio | Rol | Adaptador / config |
|---|---|---|
| `ms_iam` | Productor | `AuditAuthRestAdapter`, `AuditGatewayAdapter`; `MS_AUDIT_URL` |
| `ms_assessment` | Productor | `AuditGatewayAdapter`; `MS_AUDIT_URL` |
| `ms_catalog` | Productor | `AuditGatewayAdapter`; `MS_AUDIT_URL` |
| Frontend (admin) | Consumidor consulta | JWT contra `:8088/audit/**` |
| Compose | Orquestación | servicio `ms-audit`, imagen `mspi/ms-audit:dev` |
