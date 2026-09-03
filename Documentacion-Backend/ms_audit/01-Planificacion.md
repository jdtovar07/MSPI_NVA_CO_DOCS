# ms_audit — Planificación

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Estado | **Implementado** (puerto **8088**) |
| Persistencia | Esquema `audit`, tabla `audit.audit_log` |
| Fecha | 2026-10-11 (extracción desde ms_iam) |

## Objetivo

Poseer la bitácora central del MSPI, desacoplada de identidad (`ms_iam`) y de evaluaciones (`ms_assessment`).

## Alcance

- Ingesta S2S: `POST /internal/audit/events` (API-key interna).
- Consulta admin: `GET /audit/events` (JWT `AdminSistema`).
- Sin FK a `assessment` ni `iam.user` (`assessment_id` / `actor_user_id` como UUID).

## Productores

- `ms_iam` (AUTH login) vía `AuditAuthRestAdapter`.
- `ms_assessment` vía `AuditGatewayAdapter` / `MS_AUDIT_URL`.
