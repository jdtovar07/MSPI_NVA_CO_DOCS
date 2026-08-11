# 08 · Referencia de API (consolidada)

Índice consolidado de la API expuesta por los 6 microservicios, **alineado con los controladores `*Api.java` del backend** (`MSPI_NVA_CO_MR_BACK`, revisión 2026-10-07). Para el detalle exacto de cada endpoint (parámetros, DTOs, ejemplos), la fuente de verdad sigue siendo el código y los documentos por microservicio en `Documentacion-Backend/`.

## Convenciones transversales

- **Envelope de respuesta:** `{ "meta": {...}, "data": ... }` en éxito, `{ "meta": {...}, "error": [{ "code", "message" }] }` en error.
- **Autenticación:** header `Authorization: Bearer <JWT>` emitido por Keycloak. Las rutas `/internal/**` usan `X-Internal-Api-Key` (servidor-a-servidor) y nunca se llaman desde el navegador.
- **Paginación:** estilo Spring (`page`, `size`, `content[]`, `totalElements`) en los listados.

## `ms_iam` — puerto 8082

| Grupo | Rutas | Rol requerido |
|---|---|---|
| Auth | `POST /auth/login`, `POST /auth/change-password`, `GET /auth/totp/status`, `POST /auth/totp/setup`, `POST /auth/totp/verify` | Público / autenticado |
| Usuarios | `GET/POST /users`, `GET /users/statuses`, `GET/PUT /users/{userId}`, `PATCH /users/{userId}/status`, `POST /users/{userId}/reset-password`, `POST /users/disable-by-email` | `AdminSistema` |
| Roles | `GET /roles` | `AdminSistema` |
| Sistema | `GET/PUT /system/config`, `GET /system/config/history` | `AdminSistema` |
| Auditoría | `GET /audit/events` | `AdminSistema` |
| Notificaciones | `GET /notifications`, `POST /notifications/{id}/read`, `POST /notifications/read-all` | Autenticado |
| Interno | `POST /internal/audit/events`, `POST /internal/notifications` | `X-Internal-Api-Key` |

## `ms_org` — puerto 8083

| Grupo | Rutas | Rol requerido |
|---|---|---|
| Organizaciones | `GET/POST /organizations`, `GET/PUT /organizations/{organizationId}`, `GET /organizations/my-organization` | Autenticado |
| Geografía | `GET /location/countries`, `GET /location/countries/{iso2}/states`, `GET .../states/{iso2}/cities` | Autenticado |
| Áreas base | `GET/PUT /organizations/{organizationId}/areas-base` | `AdminSistema`, `AdminInstrumento` |

## `ms_assessment` — puerto 8084

| Grupo | Rutas | Rol requerido |
|---|---|---|
| Ciclo de vida | `POST/GET /assessments`, `GET/PATCH /assessments/{id}`, `PUT .../entity-order-type`, `POST .../publish`, `POST .../clone` | Ver RBAC por miembro |
| Workflow | `GET /assessments/my-assigned`, `GET /assessments/workflow-rules`, `POST /assessments/{id}/status`, `POST .../reopen`, `GET .../status-history` | Rol de miembro + estado |
| Miembros | `GET/POST /assessments/{id}/members`, `DELETE /assessments/{id}/members/{memberId}` | `AdminSistema` (mutación) |
| Áreas y responsables | `GET/PUT /assessments/{id}/areas`, `PUT .../areas/{areaId}/topics` | Rol de miembro editor |
| Controles | `GET /assessments/{id}/controls`, `GET/PATCH .../controls/{nodeId}`, `GET .../scores/rollup` | Rol de miembro editor |
| Stewardship | `GET .../controls/stewardship`, `PATCH .../controls/{nodeId}/steward` | Rol de miembro editor |
| PHVA / Madurez / NIST | `GET/PATCH .../phva/items[/{id}]`, `.../maturity/requirements[/{id}]`, `.../nist/items[/{id}]` (+ `.../summary`) | Rol de miembro editor |
| Diagnóstico | `GET /assessments/{id}/diagnostic/dashboard`, `.../diagnostic/domain-effectiveness`, `GET .../gaps` | Autenticado |
| Interno | `GET /internal/assessments/{id}/report-export-bundle`, `GET /internal/assessments/{id}/gaps` | `X-Internal-Api-Key` |

## `ms_catalog` — puerto 8085

| Grupo | Rutas | Rol requerido |
|---|---|---|
| Catálogo de referencia (lectura) | `GET /catalog/entity-order-types`, `/template-versions/active`, `/lifting-document-items`, `/steward-roles`, `/iso-domains`, `/assessment-area-presets`, `/control-catalog-leaves`, `/control-catalog-tree`, `/control-rules`, `/scales/published`, `/nist-mappings`, `/phva-items`, `/phva-config`, `/maturity-requirements`, `/maturity-config`, `/nist-ciber-items`, `/nist-config` | Autenticado |
| Escalas (admin) | `GET/POST /catalog/scales`, `GET /catalog/scales/{id}`, `POST .../{id}/versions`, `PUT .../versions/{versionId}`, `POST .../versions/{versionId}/publish` | `AdminSistema`, `AdminInstrumento` en mutación |
| Bancos de preguntas | `GET/POST/PUT/DELETE /catalog/question-banks` (+ `.../questions`, `.../config`, duplicate) | `AdminSistema`, `AdminInstrumento` en mutación |

> **Nota:** no existe un endpoint único `GET /catalog/bundle`; el front consume los `GET /catalog/*` de referencia anteriores.

## `ms_evidence` — puerto 8086

| Grupo | Rutas | Rol requerido |
|---|---|---|
| Contexto | `GET/PATCH /assessments/{assessmentId}/context` | Rol de miembro editor |
| Alcance de procesos | `GET/PATCH /assessments/{assessmentId}/process-scope-metric` | Rol de miembro editor |
| Levantamiento | `GET /assessments/{assessmentId}/lifting-document-deliveries`, `PATCH /lifting-document-deliveries/{deliveryId}` | Autenticado |
| Archivos | `POST/GET /assessments/{assessmentId}/files`, `GET /files/{fileId}/download`, `DELETE /files/{fileId}` | Autenticado |
| Interno | `GET /internal/assessments/{id}/context`, `POST .../lifting/init`, `POST .../lifting/clone/{targetId}`, `GET .../evidence-files`, `POST .../report-outputs`, `GET /internal/files/{fileId}/download` | `X-Internal-Api-Key` |

## `ms_reporting` — puerto 8087

| Grupo | Rutas | Rol requerido |
|---|---|---|
| Jobs | `POST /reports/jobs`, `GET /reports/jobs/{jobId}` (polling) | Autenticado |
| Comparativo | `POST /reports/comparative/jobs` | Autenticado |
| Descarga | `GET /reports/jobs/{jobId}/download` | Autenticado |
