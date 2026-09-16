# 08 · Referencia de API — `ms_reporting`

**Generación de reportes** · puerto local `:8087` · 4 endpoints (4 de negocio, 0 internos).

> Generada a partir del código fuente (controladores `@RestController` y `SecurityConfig`). Si un endpoint cambia en el código, esta referencia debe regenerarse.

## Convenciones

| Aspecto | Regla |
|---|---|
| URL base (local) | `http://localhost:8087` |
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
| 3 | * | `/reports/**` | Autenticado |
| 4 | * | `/**` | Autenticado |

## Mapa de recursos

```mermaid
flowchart LR
  C(["Cliente / mf"]) --> MS["ms_reporting :8087"]
  MS --> ComparativeReportJobApi["ComparativeReportJobApi<br/>1 endpoint"]
  ComparativeReportJobApi --> ComparativeReportJobApireports("/reports")
  MS --> ReportJobApi["ReportJobApi<br/>3 endpoints"]
  ReportJobApi --> ReportJobApireports("/reports")
```

**Contexto.** Cada caja intermedia es un controlador (adaptador de entrada de la arquitectura hexagonal); las hojas son las raíces de recurso que expone. Los controladores no contienen lógica de negocio: delegan en casos de uso del módulo `domain/usecase`.

## Resumen

| Controlador | Endpoints | Raíz común |
|---|---|---|
| `ComparativeReportJobApi` | 1 | `/reports/comparative/jobs` |
| `ReportJobApi` | 3 | `/reports/jobs` |

## Endpoints de negocio

### `ComparativeReportJobApi`

| Método | Ruta | Acceso | Parámetros | Cuerpo | HTTP | Caso de uso / guarda |
|---|---|---|---|---|---|---|
| `POST` | `/reports/comparative/jobs` | JWT (cualquier rol) | — | `CreateComparativeReportJobRequest` | 200 | `CreateComparativeReportJobUseCase`, `ProcessReportJobUseCase` |

### `ReportJobApi`

| Método | Ruta | Acceso | Parámetros | Cuerpo | HTTP | Caso de uso / guarda |
|---|---|---|---|---|---|---|
| `POST` | `/reports/jobs` | JWT (cualquier rol) | — | `CreateReportJobRequest` | 200 | `CreateReportJobUseCase`, `ProcessReportJobUseCase` |
| `GET` | `/reports/jobs/{jobId}` | JWT (cualquier rol) | `jobId` | — | 200 | `GetReportJobUseCase` |
| `GET` | `/reports/jobs/{jobId}/download` | JWT (cualquier rol) | `jobId` | — | archivo | `DownloadReportJobUseCase` |

---

Ver también: [`03-Diseno.md`](03-Diseno.md) (arquitectura y modelo) · [Referencia consolidada](../../Documentacion-General/08-Referencia-API.md) · [Modelo de datos](../../Documentacion-General/Modelo-Datos-MER.md)
