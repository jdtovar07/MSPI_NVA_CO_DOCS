# ms_audit — Desarrollo

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Fecha del documento / Última revisión cruzada con código | **2026-10-19** |
| Estado | Activo |
| Alcance | Implementación real, patrones y puntos de integración de `ms_audit` |

---

## 1. Convenciones de código

- Paquete base `co.com.mspi` (plantilla compartida con el resto de microservicios MSPI).
- Lombok (`@RequiredArgsConstructor`, builders en modelos/DTOs).
- Casos de uso en `:usecase` sin Spring; beans en `UseCaseConfig` / wiring de `app-service`.
- Respuestas HTTP envueltas con `ApiResponseMapper` → `CorrectResponse`.
- Excepciones de dominio en `:common` (`ResourceNotFoundException`, `BusinessRulesOnFieldsException`, …) mapeadas por `GlobalExceptionHandler` en `api-rest`.

## 2. Patrones aplicados

| Patrón | Dónde | Detalle |
|---|---|---|
| Puerto / adaptador | `AuditEventGateway` + `AuditEventAdapter`; `RequestOwnerGateway` + `RequestOwnerGatewayAdapter` | Dominio define contrato; infra implementa |
| Filtro de seguridad dual | `InternalApiKeyFilter` + OAuth2 JWT | `/internal/**` vs `/audit/**` |
| Filtro de consulta | `AuditEventFilter` | Objeto de dominio con page/size/q/tipos/fechas/actor/requestNumber |
| RestClient tipado por Qualifier | `msAssessmentRestClient`, `msCatalogRestClient`, `msIamRestClient` | Enrutado S2S para cabeceras de solicitud |

## 3. Funcionalidades implementadas

### 3.1 Ingestión interna

`InternalAuditApi` (`infrastructure/entry-points/api-rest/.../internal/InternalAuditApi.java`) recibe `POST /internal/audit/events`, construye `AuditEvent` y delega a `RecordAuditEventUseCase`. Respuesta **202 Accepted**.

### 3.2 Consulta de eventos

`AuditApi.events` arma `AuditEventFilter` desde query params y mapea `AuditEventView` → `AuditEventResponse` (id, eventType, entityType, entityRef, actorUserName, timestamp, ipAddress, summary, requestNumber, hasAttachment).

### 3.3 Timeline de solicitud

`AuditApi.requestTrail` expone header (requestKind, requestNumber, status, subjectName, requestedByName, createdAt, reason, attachment, decisión, scheduledDeletionAt, days) + lista timeline. La cabecera proviene del dueño vía `RequestOwnerGatewayAdapter`; el timeline de `audit.audit_log` filtrado por metadata.

### 3.4 Persistencia y correlación

`AuditEventAdapter` / `AuditLogRepository`:

- Extracción de `requestNumber` desde `metadata_json`.
- Filtros SQL con `(a.metadata_json ->> 'requestNumber') = ...`.
- Resumen derivado incluyendo `requestNumber` y subject cuando existen en metadata.

### 3.5 Productores externos (fuera de este repo folder, mismos MR_BACK)

| Productor | Adaptadores |
|---|---|
| `ms_iam` | `AuditAuthRestAdapter`, `AuditGatewayAdapter` |
| `ms_assessment` | `AuditGatewayAdapter` |
| `ms_catalog` | `AuditGatewayAdapter` |

Todos apuntan a `MS_AUDIT_URL` (default local `http://localhost:8088`) con la misma `INTERNAL_API_KEY`.

## 4. Tipos de evento (observados)

Familias emitidas por productores: `AUTH_LOGIN_*`, `PASSWORD_RESET_*`, `DELETION_*`, `EXTENSION_*`, `CATALOG_DELETION_*`, `ASSESSMENT_*`. El almacenamiento es genérico por `event_type varchar(80)`.

## 5. Configuración de aplicación relevante

Archivo: `ms_audit/applications/app-service/src/main/resources/application.yaml`

- `server.port`: `${SERVER_PORT:8088}`
- `cors.allowed-origins`: `${CORS_ALLOWED_ORIGINS}`
- `app.internal-api-key`: `${INTERNAL_API_KEY:}`
- Adaptadores outbound: `MS_ASSESSMENT_URL`, `MS_CATALOG_URL`, `MS_IAM_URL` (+ misma API key)
- JWT: `JWT_ISSUER_URI`, `JWT_JWK_SET_URI`
- JPA: `ddl-auto: none`, `sql.init.mode: never`
