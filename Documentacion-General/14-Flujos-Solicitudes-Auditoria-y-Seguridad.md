# 14 · Flujos de solicitudes, auditoría central y seguridad

| Campo | Valor |
|---|---|
| Fuentes | `MSPI_NVA_CO_MR_BACK/ms_iam`, `ms_assessment`, `ms_catalog`, `ms_audit`, `ms_admin`; `Documentacion-Backend/*`; `legal/POLITICA-PRIVACIDAD-MSPI.md`; `wiki/Seguridad.md` |

> Cada afirmación cita el artefacto verificado. Donde falte evidencia aparece **TODO**.

---

## 1. Radicados legibles (`requestNumber`)

Toda solicitud aprobable lleva un radicado humano generado con secuencia SQL y prefijo fijo:

| Prefijo | Dominio | Generación (código) | Microservicio |
|---|---|---|---|
| `SOL-ELIM-%06d` | Eliminación lógica de evaluación | `AssessmentJpaAdapter` + `assessment.seq_deletion_request_number` | `ms_assessment` |
| `SOL-AMPL-%06d` | Ampliación de plazo | `AssessmentJpaAdapter` | `ms_assessment` |
| `SOL-PWD-%06d` | Reenvío de contraseña temporal | `PasswordResetRequestJpaAdapter` | `ms_iam` |
| `SOL-CAT-%06d` | Eliminación lógica de ítem de catálogo | `CatalogDeletionJpaAdapter` | `ms_catalog` |

### Ciclo de vida (común)

1. **REQUESTED** — se crea la solicitud y se emite evento `*_REQUESTED` hacia `ms_audit` con `metadata.requestNumber`.
2. **APPROVED / REJECTED / CANCELLED** — decisión de un actor autorizado; eventos homónimos.
3. **EXECUTED** — efecto aplicado (soft-delete efectivo, reset de contraseña, etc.).

La correlación en la bitácora es siempre `metadata_json ->> 'requestNumber'` (`AuditEventAdapter`, `AuditLogRepository` en `ms_audit`).

`ms_audit` resuelve la cabecera de la solicitud vía S2S según prefijo (`RequestOwnerGatewayAdapter`):

- `SOL-CAT-*` → `ms_catalog` `GET /internal/requests/{n}`
- `SOL-PWD-*` → `ms_iam` `GET /internal/requests/{n}`
- `SOL-ELIM-*` / `SOL-AMPL-*` → `ms_assessment` `GET /internal/requests/{n}`

---

## 2. Auditoría central (`ms_audit` :8088)

| Capacidad | Endpoint | Auth | Fuente |
|---|---|---|---|
| Listado filtrable | `GET /audit/events?dateFrom&dateTo&actor&requestNumber&…` | JWT `AdminSistema` | `AuditApi.java` |
| Timeline de radicado | `GET /audit/requests/{requestNumber}` | JWT `AdminSistema` | `GetRequestAuditTrailUseCase` |
| Ingesta S2S | `POST /internal/audit/events` → **202** | `X-Internal-Api-Key` | `InternalAuditApi.java` |

**Productores verificados:** `ms_iam`, `ms_assessment`, `ms_catalog` (adapters `Audit*GatewayAdapter` / `AuditAuthRestAdapter` → `MS_AUDIT_URL`).

**Eventos observados** (string libre; no hay enum en `ms_audit`):

- Auth: `AUTH_LOGIN_SUCCESS`, `AUTH_LOGIN_FAILED`, `AUTH_LOGIN_INACTIVE`
- Password: `PASSWORD_RESET_REQUESTED|APPROVED|EXECUTED|REJECTED|CANCELLED`
- Assessment: `DELETION_*`, `EXTENSION_*`, `ASSESSMENT_PUBLISHED`, `ASSESSMENT_REOPENED`, `ASSESSMENT_STATUS_CHANGE`, `ENTITY_ORDER_TYPE_CHANGED`
- Catalog: `CATALOG_DELETION_REQUESTED|APPROVED|REJECTED|CANCELLED|EXECUTED`

UI: módulo Auditoría en `mf_shell` (`environment.msAuditUrl` → `:8088`).

---

## 3. Reenvío de contraseña temporal + reset 2FA (`ms_iam`)

API (`PasswordResetRequestsApi`):

- `POST /users/{userId}/password-reset-requests`
- `GET /password-reset-requests?status=`
- `POST …/approve|reject|cancel`

Al **aprobar** (`ApprovePasswordResetUseCase`):

1. Genera contraseña temporal en Keycloak (`temporary=true`).
2. Resetea TOTP (`TotpAdapter.resetTotp` → borra fila `iam.user_totp` si existe `keycloakSub`).
3. Envía correo vía `EmailGateway` / `BrevoEmailAdapter`.
4. Emite `PASSWORD_RESET_APPROVED` + `PASSWORD_RESET_EXECUTED` a `ms_audit`.

Tabla: `iam.password_reset_request` (`PasswordResetRequestEntity`).

---

## 4. Plantilla de correo profesional (Brevo / `ms_iam`)

- Adaptador: `ms_iam/.../brevo/BrevoEmailAdapter.java` (`@ConditionalOnProperty` `app.mail.brevo.api-key`).
- Envía HTML/texto **inline** a `https://api.brevo.com/v3/smtp/email` (no se usan `templateId` de Brevo para este flujo).
- Preview estático alineado: `brevo-sender/email-preview.html`.
- Config: `app.mail.brevo.*`, `app.mail.logo-url`, `app.frontend.login-url`.

!!! todo "Plantillas Brevo con templateId"
    Si en el futuro se migran a templates versionados en Brevo, documentar IDs aquí. Hoy el cuerpo es código Java + preview HTML.

---

## 5. Borrado siempre lógico (`deleted_at`)

Regla de negocio MSPI: **nunca** borrado físico de evaluaciones, ítems de catálogo ni evidencias en operación normal.

| Dominio | Mecanismo | Fuente |
|---|---|---|
| Evaluaciones | `assessment.deleted_at`; solicitud `SOL-ELIM` → gracia `assessmentDeletionGraceDays` (ms_admin) → sweeper `SoftDeleteDueAssessmentsUseCase` | `ms_assessment` |
| Catálogo | `deleted_at` en escalas/bancos; `SOL-CAT` + `catalogDeletionGraceDays` | `ms_catalog` |
| Evidencias | `evidence_file.deleted_at`; objeto en storage se conserva | `ms_evidence` `DeleteEvidenceFileUseCase` |

---

## 6. Configuración global (`ms_admin` :8089)

Clave `mspi.system.config` (`GetSystemConfigUseCase.KEY`), defaults:

| Campo | Default | Uso |
|---|---|---|
| `assessmentDueDays` | 30 | Plazo de evaluación |
| `assessmentExtensionDays` | 15 | Días de ampliación |
| `assessmentDeletionGraceDays` | 5 | Gracia post-aprobación `SOL-ELIM` |
| `catalogDeletionGraceDays` | 5 | Gracia `SOL-CAT` |

Validación al actualizar: enteros **1–365** (`UpdateSystemConfigUseCase`). Consumidores S2S: `ms_assessment`, `ms_catalog` vía `GET /internal/system/config`.

---

## 7. Postura de seguridad (resumen) y privacidad

Controles verificados (detalle operativo en `wiki/Seguridad.md` y SDLC `06-Implementacion-Despliegue` de cada MS):

| Control | Dónde |
|---|---|
| JWT / JWK (Keycloak Resource Server) | Todos los MS |
| CORS por entorno (`CORS_ALLOWED_ORIGINS`) | Todos |
| `/internal/**` + `X-Internal-Api-Key` constant-time | Todos con canal S2S |
| SQL parametrizado / JPA | Persistencia |
| MIME allowlist + 20 MB (+ magic bytes) | `ms_evidence` |
| Lockout / rate limit login | `ms_iam` |
| Cabeceras HTTP (HSTS, CSP, nosniff, …) | nginx MF + filtros |
| Soft-delete | Dominio (sección 5) |
| Actuator `health`/`info` | Docker healthchecks |

**Política de privacidad (Ley 1581/2012):** [`legal/POLITICA-PRIVACIDAD-MSPI.md`](../legal/POLITICA-PRIVACIDAD-MSPI.md) — también en la app en `/privacidad` (`mf_shell`).

!!! todo "Marcadores jurídicos `[[ … ]]` en la política"
    Completar con el área jurídica antes de publicación oficial.
