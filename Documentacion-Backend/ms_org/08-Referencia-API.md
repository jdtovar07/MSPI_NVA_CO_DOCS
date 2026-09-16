# 08 · Referencia de API — `ms_org`

**Organizaciones y geografía** · puerto local `:8083` · 10 endpoints (10 de negocio, 0 internos).

> Generada a partir del código fuente (controladores `@RestController` y `SecurityConfig`). Si un endpoint cambia en el código, esta referencia debe regenerarse.

## Convenciones

| Aspecto | Regla |
|---|---|
| URL base (local) | `http://localhost:8083` |
| Autenticación de usuario | `Authorization: Bearer <JWT>` emitido por Keycloak; roles en `realm_access.roles` → `ROLE_*` |
| Autenticación servicio-a-servicio | Rutas `/internal/**` con cabecera `X-Internal-Api-Key` (comparación en tiempo constante) |
| Respuesta exitosa | `{ "meta": { "traceId", "timestamp" }, "data": … }` |
| Respuesta de error | `{ "meta": …, "error": [ { "code", "message" } ] }` (manejador global de excepciones) |
| Formato | JSON (`application/json`) salvo cargas de archivos (`multipart/form-data`) y descargas binarias |

## Reglas de acceso (SecurityConfig)

Se evalúan en orden; la primera regla que coincide decide. La autorización fina de negocio (miembro de la evaluación, estado, rol en la evaluación) se valida además dentro de cada caso de uso.

| # | Método | Patrón | Regla |
|---|---|---|---|
| 1 | * | `/actuator/health`, `/actuator/info` | Público |
| 2 | * | `/error` | Público |
| 3 | * | `/location/**` | Público |
| 4 | * | `/organizations/my-organization` | Rol: Lector |
| 5 | * | `/organizations/**` | Rol: Administrador del sistema |
| 6 | * | `/**` | Autenticado |

## Mapa de recursos

```mermaid
flowchart LR
  C(["Cliente / mf"]) --> MS["ms_org :8083"]
  MS --> OrganizationApi["OrganizationApi<br/>5 endpoints"]
  OrganizationApi --> OrganizationApiorganizations("/organizations")
  MS --> OrganizationAreasBaseApi["OrganizationAreasBaseApi<br/>2 endpoints"]
  OrganizationAreasBaseApi --> OrganizationAreasBaseApiorganizations("/organizations")
  MS --> LocationApi["LocationApi<br/>3 endpoints"]
  LocationApi --> LocationApilocation("/location")
```

**Contexto.** Cada caja intermedia es un controlador (adaptador de entrada de la arquitectura hexagonal); las hojas son las raíces de recurso que expone. Los controladores no contienen lógica de negocio: delegan en casos de uso del módulo `domain/usecase`.

## Resumen

| Controlador | Endpoints | Raíz común |
|---|---|---|
| `OrganizationApi` | 5 | `/organizations` |
| `OrganizationAreasBaseApi` | 2 | `/organizations/{organizationId}/areas-base` |
| `LocationApi` | 3 | `/location/countries` |

## Endpoints de negocio

### `OrganizationApi`

| Método | Ruta | Acceso | Parámetros | Cuerpo | HTTP | Caso de uso / guarda |
|---|---|---|---|---|---|---|
| `POST` | `/organizations` | JWT · Administrador del sistema | — | `OrganizationRequest` | 200 | `CreateOrganizationUseCase` |
| `GET` | `/organizations` | JWT · Administrador del sistema | `?page=0`, `?size=20`, `?name?`, `?identifier?`, `?type?`, `?status?` | — | 200 | `GetOrganizationsUseCase` |
| `GET` | `/organizations/{organizationId}` | JWT · Administrador del sistema | `organizationId` | — | 200 | `GetOrganizationByIdUseCase` |
| `PUT` | `/organizations/{organizationId}` | JWT · Administrador del sistema | `organizationId` | `OrganizationRequest` | 200 | `GetOrganizationByIdUseCase`, `UpdateOrganizationUseCase` |
| `GET` | `/organizations/my-organization` | JWT · Lector | — | — | 200 | `GetMyOrganizationUseCase` |

### `OrganizationAreasBaseApi`

| Método | Ruta | Acceso | Parámetros | Cuerpo | HTTP | Caso de uso / guarda |
|---|---|---|---|---|---|---|
| `GET` | `/organizations/{organizationId}/areas-base` | JWT · Administrador del sistema | `organizationId` | — | 200 | `GetOrganizationAreasBaseUseCase` |
| `PUT` | `/organizations/{organizationId}/areas-base` | JWT · Administrador del sistema | `organizationId` | `ReplaceOrganizationAreasBaseRequest` | 200 | `ReplaceOrganizationAreasBaseUseCase` |

### `LocationApi`

| Método | Ruta | Acceso | Parámetros | Cuerpo | HTTP | Caso de uso / guarda |
|---|---|---|---|---|---|---|
| `GET` | `/location/countries` | Público | — | — | 200 | `GetCountriesUseCase` |
| `GET` | `/location/countries/{countryIso2}/states` | Público | `countryIso2` | — | 200 | `GetStatesByCountryUseCase` |
| `GET` | `/location/countries/{countryIso2}/states/{stateIso2}/cities` | Público | `countryIso2`, `stateIso2` | — | 200 | `GetCitiesByStateUseCase` |

---

Ver también: [`03-Diseno.md`](03-Diseno.md) (arquitectura y modelo) · [Referencia consolidada](../../Documentacion-General/08-Referencia-API.md) · [Modelo de datos](../../Documentacion-General/Modelo-Datos-MER.md)
