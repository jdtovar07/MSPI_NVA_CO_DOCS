# 08 · Referencia de API — `ms_admin`

**Configuración global del sistema** · puerto local `:8089` · 4 endpoints (3 de negocio, 1 internos).

> Generada a partir del código fuente (controladores `@RestController` y `SecurityConfig`). Si un endpoint cambia en el código, esta referencia debe regenerarse.

## Convenciones

| Aspecto | Regla |
|---|---|
| URL base (local) | `http://localhost:8089` |
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
| 3 | * | `/internal/**` | Público (filtro de API-key interna) |
| 4 | * | `/system/**` | Rol: Administrador del sistema |
| 5 | * | `/**` | Autenticado |

## Mapa de recursos

```mermaid
flowchart LR
  C(["Cliente / mf"]) --> MS["ms_admin :8089"]
  MS --> InternalSystemConfigApi["InternalSystemConfigApi<br/>1 endpoint"]
  InternalSystemConfigApi --> InternalSystemConfigApiinternalsystem("/internal/system")
  MS --> SystemAdminApi["SystemAdminApi<br/>3 endpoints"]
  SystemAdminApi --> SystemAdminApisystem("/system")
```

**Contexto.** Cada caja intermedia es un controlador (adaptador de entrada de la arquitectura hexagonal); las hojas son las raíces de recurso que expone. Los controladores no contienen lógica de negocio: delegan en casos de uso del módulo `domain/usecase`.

## Resumen

| Controlador | Endpoints | Raíz común |
|---|---|---|
| `InternalSystemConfigApi` | 1 | `/internal/system/config` |
| `SystemAdminApi` | 3 | `/system/config` |

## Endpoints de negocio

### `SystemAdminApi`

| Método | Ruta | Acceso | Parámetros | Cuerpo | HTTP | Caso de uso / guarda |
|---|---|---|---|---|---|---|
| `GET` | `/system/config` | JWT · Administrador del sistema | — | — | 200 | `GetSystemConfigUseCase` |
| `PUT` | `/system/config` | JWT · Administrador del sistema | — | `UpdateSystemConfigRequest` | 200 | `UpdateSystemConfigUseCase` |
| `GET` | `/system/config/history` | JWT · Administrador del sistema | `?limit=10` | — | 200 | `GetSystemConfigHistoryUseCase` |

## Endpoints internos (servicio a servicio)

### `InternalSystemConfigApi`

| Método | Ruta | Acceso | Parámetros | Cuerpo | HTTP | Caso de uso / guarda |
|---|---|---|---|---|---|---|
| `GET` | `/internal/system/config` | API-key interna (`X-Internal-Api-Key`) | — | — | 200 | `GetSystemConfigUseCase` |

---

Ver también: [`03-Diseno.md`](03-Diseno.md) (arquitectura y modelo) · [Referencia consolidada](../../Documentacion-General/08-Referencia-API.md) · [Modelo de datos](../../Documentacion-General/Modelo-Datos-MER.md)
