# ms_admin — Planificación

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_admin` |
| Sistema | MSPI (Modelo de Seguridad y Privacidad de la Información — ISO/IEC 27001) |
| Fecha del documento / Última revisión cruzada con código | **2026-10-19** |
| Estado | Activo |
| Alcance | Fase de planificación del microservicio `ms_admin` (configuración global, puerto **8089**, esquema PostgreSQL `admin`) |

---

## 1. Contexto del sistema MSPI

MSPI agrupa microservicios Java/Spring en `MSPI_NVA_CO_MR_BACK`, orquestados localmente por `docker-config/docker/docker-compose.apps.yml`. Cada dominio posee su esquema PostgreSQL.

`ms_admin` es el **propietario de la configuración paramétrica global** del sistema. Históricamente parte de esa configuración vivía en `iam.system_config` / `iam.system_config_history`; el patch `docker-config/docker/postgres/init/patch-admin-schema.sql` crea el esquema `admin`, migra datos y elimina las tablas origen en `iam`. El frontend `mf_shell` consume el panel vía `msAdminUrl`; `ms_assessment` y `ms_catalog` leen la configuración por canal interno.

## 2. Alcance del microservicio

`ms_admin` cubre:

- **Configuración vigente** en `admin.system_config` (clave canónica `mspi.system.config`).
- **Historial append** en `admin.system_config_history` (cada cambio genera entrada de historial).
- **API de panel** (`SystemAdminApi`): `GET/PUT /system/config`, `GET /system/config/history?limit=` — JWT rol `AdminSistema`.
- **API interna S2S** (`InternalSystemConfigApi`): `GET /internal/system/config` — header `X-Internal-Api-Key`.
- **Parámetros de negocio** (defaults y validación 1–365): `assessmentDueDays=30`, `assessmentExtensionDays=15`, `assessmentDeletionGraceDays=5`, `catalogDeletionGraceDays=5`.

Fuera de alcance: bitácora (`ms_audit`), identidad (`ms_iam`), evaluaciones/catálogo más allá del consumo de estos parámetros, “salud del sistema” (retirada por decisión de producto, comentario en `SystemAdminApi`).

## 3. Objetivos

1. Centralizar parámetros globales editables por AdminSistema en un único microservicio (**8089**).
2. Exponer lectura S2S segura para `ms_assessment` y `ms_catalog` sin propagar JWT de usuario.
3. Conservar historial de cambios (quién/cuándo/resumen/versión) en tabla append-only de historial.
4. Validar rangos de días (1–365) antes de persistir.
5. Mantener Clean Architecture Gradle (`rootProject.name = 'MsAdmin'`) sin DDL automático.

## 4. Requerimientos iniciales

| ID | Requerimiento | Evidencia |
|---|---|---|
| RI-1 | Puerto HTTP 8089 | `application.yaml` (`SERVER_PORT:8089`); `README.md` |
| RI-2 | Esquema `admin` externo vía patch | `patch-admin-schema.sql`; `ddl-auto: none` |
| RI-3 | Panel shell: GET/PUT config + history | `SystemAdminApi` |
| RI-4 | Lectura interna S2S | `InternalSystemConfigApi` |
| RI-5 | Clave `mspi.system.config` + defaults de días | `GetSystemConfigUseCase` |
| RI-6 | Validación 1–365 en update | `UpdateSystemConfigUseCase.validateDays` |
| RI-7 | Consumidores: assessment, catalog, mf_shell | `SystemConfigGatewayAdapter`; `msAdminUrl` |
| RI-8 | `DB_CREDENTIAL` obligatorio | Mismo patrón Infisical/`DBCredentialConfig` de la plantilla |

## 5. Stack tecnológico (versiones verificadas)

| Componente | Versión / detalle | Evidencia |
|---|---|---|
| Lenguaje | Java 21 | `main.gradle` |
| Framework | Spring Boot **4.0.8** | `build.gradle` |
| Build | Gradle **9.3.0** | `main.gradle` |
| Seguridad | JWT Resource Server + `InternalApiKeyFilter` | `SecurityConfig` |
| Persistencia | JPA + PostgreSQL esquema `admin` | `:jpa-repository` |
| Contenedor | Temurin 21 Alpine multi-stage | `deployment/Dockerfile` (`EXPOSE 8089`) |
| Root project | `MsAdmin` | `settings.gradle` |

## 6. Estructura del proyecto

```
MsAdmin (rootProject)
├── domain/model                         → :model
├── domain/usecase                       → :usecase
├── infrastructure/helpers/common        → :common
├── infrastructure/driven-adapters/jpa-repository → :jpa-repository
├── infrastructure/entry-points/api-rest → :api-rest
└── applications/app-service             → :app-service
```

Casos de uso: `GetSystemConfigUseCase`, `UpdateSystemConfigUseCase`, `GetSystemConfigHistoryUseCase`.

## 7. Actores interesados

| Actor | Interés |
|---|---|
| AdminSistema (mf_shell) | Editar/consultar config e historial vía `msAdminUrl` → `:8089` |
| `ms_assessment` | Leer plazos/ampliación/gracia por `/internal/system/config` |
| `ms_catalog` | Leer `catalogDeletionGraceDays` por el mismo canal |
| DevOps / DBA | Aplicar `patch-admin-schema.sql`; servicio Compose `ms-admin` |
| Keycloak | JWT realm `iam` con rol `AdminSistema` |
