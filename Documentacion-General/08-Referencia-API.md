# 08 · Referencia de API (consolidada)

Índice consolidado de la API expuesta por los 6 microservicios. Para el detalle exacto de cada endpoint (parámetros, DTOs, ejemplos), la fuente de verdad son los controladores `*Api.java` de cada servicio y los documentos de contrato en cada repositorio de código (`MSPI_NVA_CO_MR_BACK/docs/`, `MSPI_NVA_CO_MR_FRONT/docs/`).

## Convenciones transversales

- **Envelope de respuesta:** `{ "meta": {...}, "data": ... }` en éxito, `{ "meta": {...}, "error": [{ "code", "message" }] }` en error.
- **Autenticación:** header `Authorization: Bearer <JWT>` emitido por Keycloak. Las rutas `/internal/**` usan `X-Internal-Api-Key` (servidor-a-servidor) y nunca se llaman desde el navegador.
- **Paginación:** estilo Spring (`page`, `size`, `content[]`, `totalElements`) en los listados.

## `ms_iam` — puerto 8082

| Grupo | Rutas | Rol requerido |
|---|---|---|
| Auth | `POST /auth/login`, `POST /auth/totp/*`, `POST /auth/change-password` | Público / autenticado |
| Usuarios | `GET/POST/PUT /users`, `GET /roles` | `AdminSistema` |
| Sistema | `GET/PUT /system/config`, `GET /system/config/history` | `AdminSistema` |
| Auditoría | `GET /audit/events` | `AdminSistema` |
| Notificaciones | `GET /notifications`, `PATCH /notifications/{id}/read`, `PATCH /notifications/read-all` | Autenticado |
| Interno | `POST /internal/audit/events`, `POST /internal/notifications` | `X-Internal-Api-Key` |

## `ms_org` — puerto 8083

| Grupo | Rutas | Rol requerido |
|---|---|---|
| Organizaciones | `GET/POST/PUT /organizations`, `GET /organizations/my-organization` | Autenticado |
| Geografía | `GET /location/countries`, `GET /location/cities` | Autenticado |
| Áreas base | `GET/PUT /organizations/{id}/areas-base` | `AdminSistema`, `AdminInstrumento` |

## `ms_assessment` — puerto 8084

| Grupo | Rutas | Rol requerido |
|---|---|---|
| Ciclo de vida | `POST/GET/PATCH /assessments` | Ver RBAC por miembro |
| Workflow | `POST /assessments/{id}/submit-review`, `/publish`, `/reopen` | Rol de miembro + estado |
| Miembros | `GET/PUT /assessments/{id}/members` | `AdminSistema` |
| Áreas y responsables | `GET/PUT /assessments/{id}/areas`, `.../areas/{areaId}/topics` | Rol de miembro editor |
| Controles | `GET /assessments/{id}/scores/rollup`, `PATCH /assessments/{id}/controls/{nodeId}` | Rol de miembro editor |
| PHVA / Madurez / NIST | `GET/PATCH .../phva/items`, `.../maturity/requirements/{id}`, `.../nist/items/{id}` | Rol de miembro editor |
| Diagnóstico | `GET /assessments/{id}/diagnostic/dashboard`, `.../gaps` | Autenticado |
| Mis evaluaciones | `GET /assessments/my-assigned` | Autenticado |

## `ms_catalog` — puerto 8085

| Grupo | Rutas | Rol requerido |
|---|---|---|
| Bundle de referencia | `GET /catalog/bundle` | Autenticado, lectura |
| Escalas | `GET/POST/PUT /catalog/scales`, `.../versions`, `.../publish` | `AdminSistema`, `AdminInstrumento` en mutación |
| Bancos de preguntas | `GET/POST/PUT/DELETE /catalog/question-banks`, `.../questions` | `AdminSistema`, `AdminInstrumento` en mutación |

## `ms_evidence` — puerto 8086

| Grupo | Rutas | Rol requerido |
|---|---|---|
| Contexto | `GET/PATCH /evidence/context` | Rol de miembro editor |
| Archivos | `POST /evidence/files` (multipart), `GET /evidence/files/{id}/download` | Autenticado |
| Levantamiento | `GET/PATCH /evidence/lifting-document-deliveries` | Autenticado |

## `ms_reporting` — puerto 8087

| Grupo | Rutas | Rol requerido |
|---|---|---|
| Jobs | `POST /reports/jobs`, `GET /reports/jobs/{id}` (polling) | Autenticado |
| Comparativo | `POST /reports/comparative/jobs` | Autenticado |
| Descarga | `GET /reports/jobs/{id}/download` | Autenticado |
