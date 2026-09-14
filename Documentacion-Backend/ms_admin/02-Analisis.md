# ms_admin — Análisis

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_admin` |
| Fecha del documento / Última revisión cruzada con código | **2026-10-19** |
| Estado | Activo |
| Alcance | Requerimientos, reglas de negocio y casos de uso de `ms_admin` |

---

## 1. Actores

| Actor | Tipo | Autenticación | Operaciones |
|---|---|---|---|
| AdminSistema | Humano | JWT + rol `AdminSistema` | `GET/PUT /system/config`, `GET /system/config/history` |
| `ms_assessment` | Sistema | `X-Internal-Api-Key` | `GET /internal/system/config` |
| `ms_catalog` | Sistema | `X-Internal-Api-Key` | `GET /internal/system/config` |
| mf_shell | Frontend | JWT (vía usuario AdminSistema) | Módulo Configuración / dashboard (`environment.msAdminUrl`) |

`SecurityConfig` exige `.hasRole("AdminSistema")` en `/system/**`. El canal `/internal/**` no usa JWT de usuario.

## 2. Requerimientos funcionales

| ID | Requerimiento | Evidencia en código |
|---|---|---|
| RF-01 | Obtener configuración global vigente (con defaults si faltan campos) | `GetSystemConfigUseCase`, `SystemAdminApi.getConfig`, `InternalSystemConfigApi` |
| RF-02 | Actualizar configuración global | `UpdateSystemConfigUseCase`, `SystemAdminApi.updateConfig` |
| RF-03 | Consultar historial de cambios con `limit` (default 10) | `GetSystemConfigHistoryUseCase`, `SystemAdminApi.configHistory` |
| RF-04 | Validar campos de días en rango 1–365 | `UpdateSystemConfigUseCase.validateDays` |
| RF-05 | Exponer lectura S2S sin JWT | `InternalSystemConfigApi` → `GET /internal/system/config` |
| RF-06 | Clave canónica `mspi.system.config` | `GetSystemConfigUseCase.KEY` |

## 3. Requerimientos no funcionales

| ID | Requerimiento | Evidencia |
|---|---|---|
| RNF-01 | JWT stateless en panel | `SecurityConfig` |
| RNF-02 | API key interna S2S | `InternalApiKeyFilter` |
| RNF-03 | Sin DDL al arranque | `application.yaml` |
| RNF-04 | Historial append (no soft-delete de history) | Tabla `admin.system_config_history` en `patch-admin-schema.sql` |
| RNF-05 | Actuator health para Compose/Dockerfile | `deployment/Dockerfile` HEALTHCHECK |
| RNF-06 | `DB_CREDENTIAL` obligatorio | Plantilla `DBCredentialConfig` |

## 4. Reglas de negocio

### 4.1 Clave y campos (`GetSystemConfigUseCase`)

| Campo JSON | Default | Constante |
|---|---|---|
| `assessmentDueDays` | **30** | `DEFAULT_ASSESSMENT_DUE_DAYS` |
| `assessmentExtensionDays` | **15** | `DEFAULT_ASSESSMENT_EXTENSION_DAYS` |
| `assessmentDeletionGraceDays` | **5** | `DEFAULT_ASSESSMENT_DELETION_GRACE_DAYS` |
| `catalogDeletionGraceDays` | **5** | `DEFAULT_CATALOG_DELETION_GRACE_DAYS` |

- Clave: `mspi.system.config`.
- Si no hay fila, se construye config vacía `version=0` y se rellenan defaults con `putIfAbsent`.
- Si hay fila parcial, solo se completan las claves ausentes.

### 4.2 Actualización (`UpdateSystemConfigUseCase`)

1. Valida cada campo de días presente: entero entre **1 y 365** (inclusive); si no, `BusinessRulesOnFieldsException`.
2. Persiste el valor JSON y actualiza metadatos de versión / `updated_at`.
3. Genera entrada de historial (append) con resumen y actor (label desde body `changedBy` o claims JWT `name` / `preferred_username`).
4. `updated_by` UUID puede quedar `null` cuando el subject Keycloak no se mapea a `iam.user.id` (comentario en `SystemAdminApi`).

### 4.3 Historial

`GET /system/config/history?limit=` (default **10**): lista entradas recientes (id, version, changedBy, changedAt, summary). Tabla `admin.system_config_history` es append-only a nivel de diseño.

## 5. Casos de uso

| Caso de uso | Actor | Resultado |
|---|---|---|
| Consultar config (panel) | AdminSistema | 200 con key/value/version/updated* |
| Actualizar config | AdminSistema | 200 config actualizada + historial append |
| Historial | AdminSistema | 200 lista limitada |
| Consultar config (S2S) | assessment/catalog | 200 misma proyección de lectura |

## 6. Consumidores

| Consumidor | Mecanismo |
|---|---|
| `ms_assessment` | `SystemConfigGatewayAdapter` → `MS_ADMIN_URL` + `INTERNAL_API_KEY` |
| `ms_catalog` | `SystemConfigGatewayAdapter` → `MS_ADMIN_URL` (default `http://localhost:8089`) |
| `mf_shell` | `environment.msAdminUrl` → módulo Configuración y conteos de dashboard |
| Compose | `MS_ADMIN_URL=http://ms-admin:8089` en `env-mspi-docker.env` |
