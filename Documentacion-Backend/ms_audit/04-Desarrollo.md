# ms_audit — Desarrollo

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Puerto | **8088** |
| Stack | Hexagonal (mismo layout que `ms_evidence`) |

## Módulos

| Módulo | Contenido |
|--------|-----------|
| `domain/model` | `AuditEvent`, `AuditEventView`, `PagedAuditEvents`, `AuditEventGateway` |
| `domain/usecase` | `RecordAuditEventUseCase`, `ListAuditEventsUseCase` |
| `jpa-repository` | `AuditLogEntity` (`schema=audit`), `AuditLogRepository`, `AuditEventAdapter` |
| `api-rest` | `AuditApi`, `InternalAuditApi` + DTOs |
| `app-service` | Security JWT + `InternalApiKeyFilter`, `UseCaseConfig` |

## Seguridad

- `/audit/**` → rol `AdminSistema`
- `/internal/**` → `permitAll` + filtro `X-Internal-Api-Key`

## Migración

`docker-config/docker/postgres/init/patch-audit-schema.sql` migra `iam.audit_log` → `audit.audit_log` y elimina la tabla antigua.
