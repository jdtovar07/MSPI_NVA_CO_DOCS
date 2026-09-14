# ms_audit — Planificación

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_audit` |
| Sistema | MSPI (Modelo de Seguridad y Privacidad de la Información — ISO/IEC 27001) |
| Estado | Activo |
| Alcance | Fase de planificación del microservicio `ms_audit` (bitácora central, puerto **8088**, esquema PostgreSQL `audit`) |

---

## 1. Contexto del sistema MSPI

MSPI es un sistema de gestión de seguridad de la información construido como un conjunto de microservicios Java/Spring independientes que colaboran vía HTTP/REST y comparten un modelo de datos lógico particionado por esquema de base de datos (uno por microservicio: `iam`, `org`, `catalog`, `evidence`, `assessment`, `audit`, `admin`, …). El repositorio contenedor `MSPI_NVA_CO_MR_BACK` agrupa cada microservicio como carpeta independiente, y `docker-config/` centraliza la orquestación local con Docker Compose (`docker-config/docker/docker-compose.apps.yml`).

`ms_audit` es el **propietario de la bitácora central** del sistema. Persistió históricamente eventos en `iam.audit_log`; el patch `docker-config/docker/postgres/init/patch-audit-schema.sql` crea el esquema `audit`, migra filas desde `iam.audit_log` (si existe) y elimina la tabla origen. Los productores (`ms_iam`, `ms_assessment`, `ms_catalog`) envían eventos por canal S2S a `POST /internal/audit/events`; el panel de administración (JWT rol `AdminSistema`) consulta eventos y timelines de solicitudes.

## 2. Alcance del microservicio

`ms_audit` cubre exclusivamente:

- **Registro append-only** de eventos de auditoría en `audit.audit_log` (sin soft-delete; sin FK a `assessment` ni `iam.user`).
- **API pública de consulta** bajo `/audit/**` (JWT, rol `AdminSistema`): listado paginado/filtrado de eventos y trail de solicitud por `requestNumber`.
- **API interna S2S** `POST /internal/audit/events` protegida con header `X-Internal-Api-Key` (comparación constant-time), respuesta **202 Accepted**.
- **Correlación por solicitud**: el número de solicitud vive en `metadata_json.requestNumber`; el timeline de `GET /audit/requests/{requestNumber}` combina eventos locales con cabecera obtenida vía `RequestOwnerGatewayAdapter` (enrutado por prefijo `SOL-CAT-` → catalog, `SOL-PWD-` → iam, `SOL-ELIM-`/`SOL-AMPL-` → assessment).

Quedan **fuera de alcance**: autenticación (`ms_iam`), evaluaciones (`ms_assessment`), catálogo (`ms_catalog`), evidencias (`ms_evidence`), configuración global (`ms_admin`), reportes (`ms_reporting`).

## 3. Objetivos

1. Centralizar la bitácora de auditoría del ecosistema MSPI en un único esquema `audit` y puerto **8088**.
2. Permitir a microservicios productores emitir eventos sin JWT de usuario, con `INTERNAL_API_KEY` compartida.
3. Exponer al administrador de sistema consultas filtrables y el timeline de solicitudes correlacionadas por `requestNumber`.
4. Mantener desacople de dominios: `assessment_id` y `actor_user_id` son UUID opcionales **sin FK** cross-schema.
5. Aplicar Clean Architecture multi-módulo Gradle (`rootProject.name = 'MsAudit'`) sin DDL automático al arranque.

## 4. Requerimientos iniciales

| ID | Requerimiento | Evidencia |
|---|---|---|
| RI-1 | Puerto HTTP por defecto 8088 | `applications/app-service/src/main/resources/application.yaml` (`SERVER_PORT:8088`) |
| RI-2 | Esquema `audit.audit_log` versionado externamente; sin DDL al arranque | `spring.sql.init.mode: never`, `hibernate.ddl-auto: none`; `patch-audit-schema.sql` |
| RI-3 | Ingestión S2S con API key y respuesta 202 | `InternalAuditApi`, `InternalApiKeyFilter` (`MessageDigest.isEqual`) |
| RI-4 | Consulta pública restringida a `AdminSistema` | `SecurityConfig`: `.requestMatchers("/audit/**").hasRole("AdminSistema")` |
| RI-5 | Consumidores conocen `MS_AUDIT_URL` | p. ej. `ms_iam` / `ms_catalog` / `ms_assessment` `application.yaml` (`MS_AUDIT_URL` default `http://localhost:8088`) |
| RI-6 | Credencial DB obligatoria (`DB_CREDENTIAL`); sin fallback H2 | `DBCredentialConfig` |
| RI-7 | Health checks Actuator para Docker | `deployment/Dockerfile` `HEALTHCHECK` → `/actuator/health` |

## 5. Stack tecnológico (versiones verificadas)

| Componente | Versión / detalle | Evidencia |
|---|---|---|
| Lenguaje | Java 21 | `main.gradle`: `JavaLanguageVersion.of(21)` |
| Framework | Spring Boot **4.0.8** | `build.gradle`: `springBootVersion = '4.0.8'` |
| Build | Gradle **9.3.0** (wrapper) | `main.gradle` |
| Modelo web | Spring MVC (servlet) | módulo `:api-rest` |
| Seguridad | OAuth2 Resource Server (JWT) + `InternalApiKeyFilter` | `SecurityConfig`, `InternalApiKeyFilter` |
| Persistencia | Spring Data JPA + PostgreSQL | `:jpa-repository` |
| Secretos | Infisical SDK + `DB_CREDENTIAL` | `InfisicalConfig`, `DBCredentialConfig` |
| Contenedor | `eclipse-temurin:21-jdk-alpine` → `21-jre-alpine` | `deployment/Dockerfile` |
| Root project | `MsAudit` | `settings.gradle` |

## 6. Estructura del proyecto (multi-módulo Gradle)

```
MsAudit (rootProject)
├── domain/model                         → :model
├── domain/usecase                       → :usecase
├── infrastructure/helpers/common        → :common
├── infrastructure/driven-adapters/jpa-repository → :jpa-repository
├── infrastructure/entry-points/api-rest → :api-rest
└── applications/app-service             → :app-service
```

Casos de uso de dominio: `RecordAuditEventUseCase`, `ListAuditEventsUseCase`, `GetRequestAuditTrailUseCase`. El adaptador `RequestOwnerGatewayAdapter` vive en `app-service` (`co.com.mspi.consumer`) y consume APIs internas de assessment/catalog/iam.

## 7. Actores interesados

| Actor | Interés |
|---|---|
| AdminSistema (frontend / mf_shell) | `GET /audit/events`, `GET /audit/requests/{requestNumber}` con JWT |
| `ms_iam` | Productor: `AuditAuthRestAdapter`, `AuditGatewayAdapter` → `POST /internal/audit/events` |
| `ms_assessment` | Productor: `AuditGatewayAdapter` |
| `ms_catalog` | Productor: `AuditGatewayAdapter` |
| DevOps / DBA | Aplicar `patch-audit-schema.sql`; orquestar servicio Compose `ms-audit` |
| Keycloak | Emisor JWT realm `iam` |
