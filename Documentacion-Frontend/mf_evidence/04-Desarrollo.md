# mf_evidence — Desarrollo

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_evidence`
**Fecha del documento:** 2026-08-18
**Alcance:** Implementación real del microfrontend: manejo de estado, servicios, componentes, patrones aplicados e integración con la API backend (`ms_evidence`), basado en `docs/API-INTEGRACION.md` y en el código fuente de `src/app`.

---

## 1. Manejo de estado

`mf_evidence` no usa ninguna librería de gestión de estado global (no hay NgRx, Akita ni similares en `package.json`). El estado se maneja íntegramente con **Angular Signals**:

- **Estado de sesión** — `AuthSessionService` (`src/app/domain/auth/auth-session.service.ts`):
  ```ts
  private readonly sessionSignal = signal<StoredSession | null>(this.read());
  readonly token = computed(() => { ... });
  readonly isAuthenticated = computed(() => { ... });
  reload(): void { this.sessionSignal.set(this.read()); }
  ```
  A diferencia de `mf_auth`, esta versión de `AuthSessionService` es de **solo lectura**: no expone `setSession()`/`clearSession()`, únicamente `reload()`. Esto es consistente con el rol de `mf_evidence` en la integración (consume la sesión, no la origina — ver `03-Diseno.md`, sección 4.3). La lectura contempla tres fuentes en orden: `localStorage`, `sessionStorage`, y como último recurso la cookie `auth_session`.

- **Estado local de página** — cada una de las tres páginas usa `signal()` para banderas de UI:
  - `EvidenceHomePageComponent`: `assessmentId = signal<string | null>(null)`.
  - `ContextPageComponent`: `loading`, `saving`, `message`, `contextFiles`.
  - `InventoryPageComponent`: `loading`, `savingMetric`, `message`, `deliveries`, `metric`, `liftingFiles`.
  - `FileUploaderComponent`: `dragging`, `uploading`, `error`.

- **Estado derivado (`computed`)**: se usa de forma más limitada que en `mf_auth` (por ejemplo `token`/`isAuthenticated` en `AuthSessionService`); los cómputos por componente (`stepNumber`, `totalSteps`, `currentStepLabel` en `EvidenceFlowNavComponent`) se implementan como **getters de clase**, no como `computed()`, porque dependen de `@Input()` (propiedades planas), no de signals.

- **Formularios**: se usa `FormsModule` (formularios *template-driven*) con `[(ngModel)]`/`[ngModel]`+`(ngModelChange)`, no `ReactiveFormsModule`, igual que en `mf_auth`. El formulario de contexto (`ContextPageComponent.form`) es una propiedad de clase plana (no signal), reasignada por inmutabilidad (`this.form = {...ctx}`) tras cada carga o guardado.

## 2. Servicios

| Servicio/función | Capa | Rol |
|---|---|---|
| `AuthSessionService` | domain | Lectura reactiva del estado de sesión (`localStorage`/`sessionStorage`/cookie) |
| `GetContextUseCase`, `PatchContextUseCase` | application | CRUD del contexto de evaluación |
| `GetProcessScopeMetricUseCase`, `PatchProcessScopeMetricUseCase` | application | Lectura/actualización de la métrica de alcance de procesos |
| `GetLiftingDeliveriesUseCase`, `PatchLiftingDeliveryUseCase` | application | Lectura/actualización de las 43 entregas de levantamiento |
| `UploadEvidenceFileUseCase`, `ListEvidenceFilesUseCase` | application | Subida y listado de archivos, parametrizados por `relationType`/`relationId`/`contextField` |
| `FileDownloadService` | application | Descarga de archivos vía blob y enlace temporal |
| `apiInterceptor` | infrastructure | Interceptor funcional: autenticación saliente, normalización de respuesta, manejo de 401 |
| `installAuthParentBridge` | infrastructure | Recepción de sesión JWT desde el shell vía `postMessage` |
| `openShellRoute` | infrastructure | Envío de navegación/evaluación activa hacia el shell |

Los 8 casos de uso de `evidence.use-cases.ts` siguen exactamente el mismo patrón de una sola responsabilidad: reciben `EvidenceRepository` por inyección de constructor y exponen un único método `execute(...)` que delega directamente en el repositorio, sin lógica adicional propia (a diferencia de `mf_auth`, donde algunos casos de uso sí orquestan más de una llamada). Esto los convierte, en la práctica, en un delgado *pass-through* tipado que documenta la intención de cada operación y desacopla las páginas del contrato exacto de `EvidenceRepository`.

## 3. Componentes (páginas)

Las 3 páginas de presentación son **standalone components** con plantilla y estilos **inline** (`template`/`styles` dentro del mismo `.ts`, sin archivos `.html`/`.scss` separados), a diferencia del patrón mixto de `mf_auth`. Todas siguen el mismo patrón interno:

1. Inyección de casos de uso por constructor (`private readonly` en cada uno).
2. Lectura de `assessmentId` desde `ActivatedRoute.snapshot.paramMap` en `ngOnInit()`.
3. Método privado `load()` async que llama a uno o varios casos de uso (en `InventoryPageComponent`, en paralelo con `Promise.all`) y actualiza signals.
4. Métodos públicos de mutación (`save()`, `saveMetric()`, `updateStatus()`, `uploadMission()`, etc.) que envuelven la llamada en `try/catch`, actualizan un signal `message` con el resultado (éxito o `err.message`) y, en el caso del levantamiento, recargan el estado completo tras cada mutación.

Extracto real representativo — `InventoryPageComponent.updateDeliveredName()`, mostrando el patrón de "solo mutar si cambió" y recarga completa:

```ts
async updateDeliveredName(item: LiftingDelivery, name: string): Promise<void> {
  if (name === (item.deliveredName ?? '')) return;
  await this.patchDelivery.execute(this.assessmentId, item.id, {
    deliveryStatus: item.deliveryStatus,
    deliveredName: name,
    notes: item.notes,
  });
  await this.load();
}
```

## 4. Patrones aplicados

- **Repository Pattern / Ports & Adapters**: un único puerto abstracto (`EvidenceRepository`) con dos adaptadores, `ApiEvidenceRepository` y `MockEvidenceRepository`.
- **Strategy vía DI**: la elección de adaptador (mock/API) es una decisión de configuración centralizada en `app.config.ts`.
- **Interceptor / Middleware HTTP**: `apiInterceptor` centraliza autenticación saliente, desenvolvimiento del sobre `{data, meta}` y normalización de errores a `ApiError`, evitando repetir esta lógica en cada método de `ApiEvidenceRepository`.
- **Adapter de manejo de error uniforme**: la función `toApiError()` (privada, en `api-evidence.repository.ts`) se reutiliza con `.catch(toApiError)` encadenado en los 10 métodos HTTP del repositorio, evitando duplicar el bloque `try/catch` en cada uno.
- **Command/Query separados por caso de uso**: cada operación de lectura (`Get*UseCase`) y de escritura (`Patch*UseCase`/`Upload*UseCase`) es una clase independiente de responsabilidad única, en vez de un único servicio con múltiples métodos.
- **Emisión de eventos desacoplada en componentes reutilizables**: `FileUploaderComponent` no conoce el destino del archivo (contexto o levantamiento); solo emite `@Output() fileSelected = new EventEmitter<File>()`, delegando la decisión de qué caso de uso invocar al componente padre — patrón de "componente tonto" (*dumb component*) clásico.
- **Mock funcionalmente equivalente al backend real**: `MockEvidenceRepository` replica el cálculo de cobertura (`Math.round((inScopeProcesses/totalProcesses)*100)`) y el versionado incremental que se espera del backend real, permitiendo desarrollo y demostración sin `ms_evidence` disponible.

## 5. Integración con la API backend (`ms_evidence`)

Basado en `docs/API-INTEGRACION.md` y verificado directamente en `api-evidence.repository.ts`.

### 5.1 `ms_evidence` (puerto 8086) — vía `environment.msEvidenceUrl`

| Endpoint | Método | Usado por | Notas |
|---|---|---|---|
| `/assessments/{id}/context` | `GET` | `ApiEvidenceRepository.getContext()` | Devuelve `AssessmentContext` |
| `/assessments/{id}/context` | `PATCH` | `ApiEvidenceRepository.patchContext()` | Body: `PatchContextRequest` (campos opcionales) |
| `/assessments/{id}/process-scope-metric` | `GET` | `ApiEvidenceRepository.getProcessScopeMetric()` | Devuelve `ProcessScopeMetric` (incluye `coverage`, `inScopeExceedsTotal`) |
| `/assessments/{id}/process-scope-metric` | `PATCH` | `ApiEvidenceRepository.patchProcessScopeMetric()` | Body: `{totalProcesses, inScopeProcesses}` |
| `/assessments/{id}/lifting-document-deliveries` | `GET` | `ApiEvidenceRepository.getLiftingDeliveries()` | Devuelve `LiftingDelivery[]` (43 ítems esperados) |
| `/lifting-document-deliveries/{deliveryId}` | `PATCH` | `ApiEvidenceRepository.patchLiftingDelivery()` | Body: `PatchLiftingDeliveryRequest`; `deliveryId` codificado con `encodeURIComponent` |
| `/assessments/{id}/files` | `POST` | `ApiEvidenceRepository.uploadFile()` | `multipart/form-data`: `file`, `relationType`, `relationId?`, `contextField?` |
| `/assessments/{id}/files` | `GET` | `ApiEvidenceRepository.listFiles()` | Query params opcionales `relationType`, `relationId` |
| `/files/{fileId}/download` | `GET` | `ApiEvidenceRepository.downloadFile()` | `responseType: 'blob'` |
| `/files/{fileId}` | `DELETE` | `ApiEvidenceRepository.deleteFile()` | Expuesto en el repositorio y el dominio; **sin uso desde ninguna página** (ver limitación en sección 8) |

### 5.2 Contrato de sobre de respuesta

Igual que en `mf_auth`, se asume un formato envolvente `{meta, data}` en éxito y `{meta, error}` en fallo (`api-response.model.ts` define `ApiError`/`ErrorDetail`; el desenvolvimiento ocurre en `apiInterceptor`):

```ts
const body = event.body as { data?: unknown; meta?: unknown } | null;
if (body && body.data !== undefined && body.meta) {
  return event.clone({ body: body.data });
}
```

Con una salvedad explícita en el interceptor: si el cuerpo de la respuesta es un `Blob` (caso de `downloadFile()`), se omite el desenvolvimiento (`if (event.body instanceof Blob) return event;`), evitando corromper la descarga de archivos binarios.

### 5.3 Manejo de errores HTTP

`apiInterceptor` convierte cualquier `HttpErrorResponse` en un `ApiError` tipado, de forma idéntica a `mf_auth`:

```ts
catchError((err: HttpErrorResponse) => {
  if (err.status === 401) {
    inject(AuthSessionService).reload();
  }
  const apiError = new ApiError(
    err.status,
    err.error?.error ?? [{ code: 'UNKNOWN', message: err.message }],
    err.error?.meta?.traceId
  );
  return throwError(() => apiError);
})
```

**Diferencia relevante frente a `mf_auth`:** en 401, `mf_evidence` **recarga** la sesión (`reload()`) en vez de **limpiarla** (`clearSession()`), lo cual es coherente con que `AuthSessionService` de este microfrontend no expone un método de limpieza — la responsabilidad de invalidar la sesión persistida recae en `mf_auth`/el shell, no en `mf_evidence`.

A nivel de repositorio, `ApiEvidenceRepository` reutiliza la función privada `toApiError()` para relanzar el `ApiError` en todas las llamadas HTTP; a nivel de página, el `catch` de cada método (`save()`, `saveMetric()`, `uploadContext()`) usa `err instanceof Error ? err.message : 'Error al guardar'` como mensaje mostrado al usuario — sin mapeo a códigos de negocio legibles como sí ocurre en `mf_auth` (`errorMessage(code)`), es decir, se muestra el mensaje crudo devuelto por el backend.

## 6. Funcionalidades desarrolladas (resumen funcional)

1. **Redirección/aviso según evaluación activa** en la pantalla de inicio, sin backend involucrado (solo lectura de `localStorage`).
2. **Formulario de contexto de evaluación** con 7 campos de texto (misión, análisis de contexto, mapa de procesos, organigrama, y 3 de autopercepción), persistencia incremental vía `PATCH`.
3. **Carga de archivos de contexto** diferenciada por campo (`MISSION`/`CONTEXT`), con listado y descarga de los ya subidos.
4. **Levantamiento documental de 43 ítems** con edición inline de estado (`select`) y nombre entregado (`input` con `blur`), y carga de archivo por fila.
5. **Métrica de alcance de procesos** (ítem 43) con cálculo de cobertura y alerta visual de inconsistencia (alcance > total).
6. **Descarga uniforme de archivos** (contexto y levantamiento) reutilizando `FileDownloadService` en ambas páginas.
7. **Navegación de flujo de dos pasos** con indicador de paso actual y salida hacia el shell, mediante un componente reutilizable único (`EvidenceFlowNavComponent`) parametrizado por `@Input()`.
8. **Modo mock funcionalmente completo**, incluyendo generación determinista de 43 entregas con nombres de documento cíclicos (`DOC_NAMES`) y estados variados (5 `DELIVERED`, 3 `PARTIAL`, 35 `NOT_DELIVERED`) para facilitar pruebas manuales exploratorias.

## 7. Convenciones de código observadas

- Nomenclatura de archivos en `kebab-case` con sufijo por rol arquitectónico: `*.repository.ts`, `*.use-cases.ts` (plural, único archivo con 8 clases), `*.service.ts`, `*-page.component.ts`.
- Clases de dominio en `PascalCase`; tipos/interfaces también en `PascalCase` (`AssessmentContext`, `LiftingDelivery`).
- Uso extensivo de `readonly` en propiedades inyectadas por constructor (`private readonly repository: EvidenceRepository`).
- Uso de `type` imports explícitos (`import type { ... } from '../../domain/evidence/evidence.types'`) para los tipos de solo compilación, separados de los imports de valor — práctica que reduce el peso del bundle y hace explícita la intención (tipo vs. valor).
- TypeScript en modo `strict` real: no se observa uso de `any` en el código inspeccionado; los manejadores de eventos de formulario usan *type casts* explícitos y acotados (`$any($event.target).value` en la plantilla de `InventoryPageComponent`, necesario porque Angular no tipa `$event.target` de forma nativa en las plantillas).

## 8. Limitaciones de implementación observadas

- **`deleteFile()` está definido en el dominio y en ambos repositorios (`ApiEvidenceRepository`, `MockEvidenceRepository`) pero no se invoca desde ninguna página**: no existe botón "Eliminar" en `ContextPageComponent` ni en `InventoryPageComponent`; la capacidad de borrar un archivo adjunto existe en la capa de datos pero no está expuesta en la UI.
- **Sin manejo de control de concurrencia en UI**: `AssessmentContext.version` y `LiftingDelivery.version` se reciben del backend/mock pero no se reenvían en las peticiones `PATCH` ni se usan para detectar conflictos de edición concurrente (confirmado en `04-Desarrollo.md`/`02-Analisis.md`, regla de negocio 10).
- **`FileUploaderComponent.uploading`/`error` (signals internas) no están conectadas al flujo real de subida**: el componente declara y renderiza condicionalmente `@if (uploading())`/`@if (error())`, pero ningún código en `ContextPageComponent`/`InventoryPageComponent` invoca `uploader.uploading.set(true)` ni captura errores hacia esas señales; el estado real de "subiendo"/error de la subida se refleja únicamente en el signal `message` de la página contenedora, no en el propio componente de subida.
- **Recarga completa tras cada mutación de levantamiento** (`await this.load()`): funcionalmente correcta pero implica una petición HTTP adicional (o más, dado el `Promise.all` de tres llamadas) tras cada cambio de estado o nombre entregado, en vez de actualizar el elemento localmente en el array `deliveries()`.
- **Sin *route guards* que validen `assessmentId`**: cualquier valor de `assessmentId` en la URL es aceptado sin verificación previa de existencia o pertenencia (ver `03-Diseno.md`, sección 6.8).
