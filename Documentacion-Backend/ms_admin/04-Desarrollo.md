# ms_admin — Desarrollo

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_admin` |
| Estado | Activo |
| Alcance | Implementación, patrones e integraciones de `ms_admin` |

---

## 1. Convenciones

- Paquete `co.com.mspi`, Lombok, casos de uso sin Spring en `:usecase`.
- DTOs de API en `api-rest` (`SystemConfigResponse`, `UpdateSystemConfigRequest`, `SystemConfigHistoryResponse`).
- Envelope `CorrectResponse` / `ApiResponseMapper`.
- Documentación auxiliar en repo: `ms_admin/README.md`, `ms_admin/docs/MIGRATION-NOTES.md`, `ms_admin/docs/ROADMAP.md`.

## 2. Patrones

| Patrón | Dónde |
|---|---|
| Puerto / adaptador | `SystemConfigGateway` + implementación JPA |
| Merge de defaults | `GetSystemConfigUseCase.execute` con `putIfAbsent` |
| Validación de dominio | `UpdateSystemConfigUseCase.validateDays` → `BusinessRulesOnFieldsException` |
| Dual auth | JWT en `/system/**`, API key en `/internal/**` |
| Historial append | Persistencia de snapshot en `system_config_history` al actualizar |

## 3. Funcionalidades implementadas

### 3.1 Lectura de configuración

`GetSystemConfigUseCase` busca `mspi.system.config`; si no existe, sintetiza config vacía `version=0` y aplica defaults 30/15/5/5. Usada tanto por panel como por canal interno.

### 3.2 Actualización

`SystemAdminApi.updateConfig`:

- Recibe mapa `config` y opcional `changedBy`.
- Label de actor: `changedBy` o `jwt.name` / `preferred_username`.
- UUID interno `updated_by` se pasa como `null` desde el controlador (limitación de mapeo subject Keycloak ↔ `iam.user.id` documentada en código).
- `UpdateSystemConfigUseCase` valida rangos y persiste config + historial.

### 3.3 Historial

`GetSystemConfigHistoryUseCase.execute(limit)` proyecta filas a respuesta con id, version, changedBy, changedAt, summary.

### 3.4 Canal interno

`InternalSystemConfigApi` reutiliza `GetSystemConfigUseCase` — una sola fuente de verdad de lectura para S2S.

## 4. Integraciones consumidoras

| Consumidor | Evidencia |
|---|---|
| `ms_assessment` | `SystemConfigGatewayAdapter` + `MS_ADMIN_URL` |
| `ms_catalog` | `SystemConfigGatewayAdapter`; YAML `url: ${MS_ADMIN_URL:http://localhost:8089}` |
| `mf_shell` | `msAdminUrl` (local tip. `http://localhost:8089`) — Configuración y dashboard |

## 5. Configuración de aplicación

`ms_admin/applications/app-service/src/main/resources/application.yaml`:

- `server.port`: `${SERVER_PORT:8089}`
- `cors.allowed-origins`: `${CORS_ALLOWED_ORIGINS}`
- `app.internal-api-key`: `${INTERNAL_API_KEY:}`
- JWT: `JWT_ISSUER_URI`, `JWT_JWK_SET_URI`
- JPA: `ddl-auto: none`, `sql.init.mode: never`
- `spring.application.name: admin`
