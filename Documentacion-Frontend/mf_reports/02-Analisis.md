# mf_reports — Análisis

**Repositorio:** `MSPI_NVA_CO_MR_FRONT/mf_reports`
**Fecha del documento:** 2026-08-18
**Alcance:** Requerimientos funcionales y no funcionales, reglas de negocio, actores, casos de uso y flujos del microfrontend `mf_reports`, derivados de la lectura directa del código fuente y de la documentación técnica preexistente en `docs/`.

---

## 1. Actores

| Actor | Descripción | Evidencia |
|---|---|---|
| **Usuario con evaluación activa** | Cualquier usuario autenticado en MSPI que tiene una evaluación diligenciada en `mf_assessment` (su id persiste en `localStorage` bajo `active_assessment_id`). Puede ver el diagnóstico consolidado y generar reportes. | `reports-home-page.component.ts` |
| **Usuario sin evaluación activa** | Usuario autenticado que aún no ha creado/abierto una evaluación. Solo ve un mensaje informativo y un enlace a un tablero de demostración (`mock-assessment-1`). | `reports-home-page.component.ts` |
| **`mf_shell` (host)** | Actor de sistema: embebe `mf_reports` en un iframe, reenvía la sesión de autenticación por `postMessage`, y navega directamente a `/assessments/:id/dashboard` cuando detecta una evaluación activa. | `docs/INTEGRACION-SHELL.md`, `auth-parent-bridge.ts` |
| **`mf_assessment` (microfrontend de evaluaciones)** | Actor de sistema: desde su módulo NIST invoca `openShellRoute('/reports', id)` para llevar al usuario al diagnóstico de una evaluación específica. | `docs/INTEGRACION-SHELL.md` |
| **`ms_reporting` (backend, puerto 8087)** | Sistema externo que genera los archivos PDF/Excel de forma asíncrona mediante *jobs*, y los almacena disponibles para descarga. | `docs/API-INTEGRACION.md`, `api-reporting.repository.ts` |
| **`ms_assessment` (backend, puerto 8084)** | Sistema externo que provee los datos agregados de diagnóstico (dominios ISO, PHVA, madurez, NIST) y el listado de brechas de una evaluación. | `docs/API-INTEGRACION.md`, `api-reporting.repository.ts` |

No existe en el código un modelo de roles/autoridades propio de `mf_reports` (a diferencia de `mf_auth`, que expone `authority.ts` con `USER_MANAGE`); el control de acceso a la funcionalidad de exportación se referencia únicamente de forma textual en la interfaz ("Requiere **REPORT_EXPORT**", en `reports-export-page.component.ts`), sin que el código realice ninguna verificación de esa autoridad del lado del microfrontend — se declara explícitamente como hallazgo.

## 2. Requerimientos funcionales

| ID | Requerimiento | Evidencia en código |
|---|---|---|
| RF-01 | El sistema debe detectar si existe una evaluación activa (`active_assessment_id` en `localStorage`) al cargar la pantalla de inicio. | `reports-home-page.component.ts`, `ngOnInit` |
| RF-02 | Si hay evaluación activa, el sistema debe permitir navegar directamente a su tablero de diagnóstico. | `reports-home-page.component.ts`, `openDashboard()` |
| RF-03 | Si no hay evaluación activa, el sistema debe ofrecer un modo demo con un identificador fijo (`mock-assessment-1`). | `reports-home-page.component.ts`, `openDemo()` |
| RF-04 | El sistema debe obtener y consolidar en un solo modelo (`DiagnosticDashboard`) los datos de: portada ISO por dominio, ciclo PHVA, matriz de madurez, funciones NIST CSF y listado de brechas, para una evaluación dada. | `reporting.repository.ts`, `api-reporting.repository.ts::getDiagnosticDashboard` |
| RF-05 | El sistema debe calcular un promedio global y una etiqueta de banda (Inexistente/Inicial/Gestionado/Definido/Optimizado) para el puntaje ISO cuando el backend no la provea. | `reporting-diagnostic.mapper.ts::bandLabel`, `mapDomains` |
| RF-06 | El tablero de diagnóstico consolidado se visualiza en el hub de la evaluación (`mf_assessment`); en `mf_reports` la ruta histórica de dashboard redirige a exportación de reportes. | `diagnostic-dashboard-page.component.ts` (redirect → `/export`) |
| RF-07 | El sistema debe permitir crear un trabajo (*job*) de generación de reporte, indicando el tipo de reporte deseado, para una evaluación. | `reports-export-page.component.ts::generate()`, `reporting.repository.ts::createReportJob` |
| RF-08 | El sistema debe soportar, como mínimo, 4 tipos de reporte accionables desde la interfaz: `FULL_DIAGNOSTIC_PDF`, `EXCEL_INSTRUMENT_EXPORT`, `GAP_LIST_PDF`, `GAP_LIST_XLSX`. | `reports-export-page.component.ts`, botones de `generate()` |
| RF-09 | El sistema debe soportar a nivel de dominio la creación de reportes comparativos entre varias evaluaciones (`COMPARATIVE_DIAGNOSTIC_PDF`/`_XLSX`), aunque sin pantalla propia que lo invoque. | `reporting.repository.ts::createComparativeReportJob`, `reporting.types.ts::CreateComparativeReportJobRequest` |
| RF-10 | El sistema debe consultar periódicamente (*polling*) el estado del *job* creado hasta que finalice (`COMPLETED`, `FAILED` o `CANCELLED`) o expire un tiempo máximo. | `reports-export-page.component.ts::startPoll/pollOnce`, intervalo 2500 ms, tope 5 min |
| RF-11 | El sistema debe mostrar el progreso porcentual del *job* mientras esté en estado `RUNNING`, cuando el backend lo informe. | `reports-export-page.component.ts`, propiedad `progressPct` |
| RF-12 | Al completarse el *job*, el sistema debe descargar automáticamente el archivo resultante. | `reports-export-page.component.ts::pollOnce`, bandera `autoDownloaded` |
| RF-13 | El sistema debe permitir también una descarga manual del archivo mientras el *job* esté en estado `COMPLETED` (botón "Descargar archivo"). | `reports-export-page.component.ts`, template |
| RF-14 | El sistema debe resolver el nombre y la extensión del archivo descargado, priorizando el encabezado `Content-Disposition` del backend y aplicando un nombre y extensión de reserva (*fallback*) según el tipo de reporte cuando dicho encabezado no exista o sea incompleto. | `report-filename.util.ts` |
| RF-15 | El sistema debe forzar la extensión `.xlsx` para el tipo `EXCEL_INSTRUMENT_EXPORT`, ya que su nombre no sigue el patrón `_XLSX` de los demás tipos Excel. | `report-filename.util.ts::isExcelReportType` |
| RF-16 | El sistema debe distinguir una respuesta de error JSON disfrazada de descarga binaria (mismo *endpoint* de descarga devolviendo `application/json` en vez del archivo) y extraer el mensaje de error para mostrarlo al usuario. | `report-download.helper.ts::mapReportDownloadResponse/parseJsonBlobError` |
| RF-17 | El sistema debe mostrar el mensaje de error específico del *job* (`errorMessage`) cuando su estado sea `FAILED`. | `reports-export-page.component.ts`, template, sección `@if (job()!.status === 'FAILED')` |
| RF-18 | El sistema debe indicar de forma informativa, sin ser el mecanismo de descarga, que existe una copia archivada del reporte en evidencias (`outputFileId`). | `reports-export-page.component.ts`, template |
| RF-19 | El sistema debe sincronizar la sesión de autenticación recibida del shell (`mf_shell`) vía `postMessage`, actualizando el estado local (`AuthSessionService`) cuando llegue un mensaje válido. | `auth-parent-bridge.ts`, `app.component.ts` |
| RF-20 | El sistema debe adjuntar el token de sesión como cabecera `Authorization: Bearer` en cada solicitud HTTP saliente, cuando exista sesión válida. | `api.interceptor.ts` |
| RF-21 | El sistema debe desempaquetar automáticamente el sobre `{ data, meta }` (`CorrectResponse`) de las respuestas HTTP JSON exitosas, dejando pasar sin modificar las respuestas de tipo `Blob` (descargas binarias). | `api.interceptor.ts` |
| RF-22 | El sistema debe operar en modo simulado (mock) completo, sin backend real, incluyendo la evolución temporal de un *job* de `PENDING` a `RUNNING` y luego a `COMPLETED`. | `mock-reporting.repository.ts` |

## 3. Requerimientos no funcionales

| ID | Requerimiento | Evidencia |
|---|---|---|
| RNF-01 | El microfrontend debe ejecutarse como aplicación independiente en el puerto 4205. | `angular.json`, `architect.serve.options.port` |
| RNF-02 | El microfrontend debe poder embeberse en un iframe únicamente desde los orígenes del shell autorizado (`http://localhost:4200`, `http://127.0.0.1:4200`). | `deployment/nginx.conf`, cabecera `Content-Security-Policy: frame-ancestors` |
| RNF-03 | El código de la capa de dominio (`domain/`) no debe depender de Angular ni de HTTP; solo expone contratos abstractos y tipos. | `reporting.repository.ts` (clase abstracta), `reporting.types.ts` (tipos puros) |
| RNF-04 | El origen de datos (mock vs. API real) debe ser intercambiable por configuración de build, sin modificar componentes de presentación. | `app.config.ts`, selección de `useClass` según `environment.useMocks` |
| RNF-05 | El *build* de producción debe optimizar y aplicar *hashing* de salida a los artefactos. | `angular.json`, configuración `production: { outputHashing: "all" }` |
| RNF-06 | Los archivos estáticos (JS, CSS, imágenes, fuentes) deben servirse con caché de larga duración (7 días) en el servidor de despliegue. | `deployment/nginx.conf`, bloque `location ~* \.(js|css|...)$` |
| RNF-07 | El contenedor de despliegue debe exponer un *healthcheck* HTTP. | `deployment/Dockerfile`, instrucción `HEALTHCHECK` |
| RNF-08 | El código TypeScript debe compilarse en modo estricto, incluyendo verificación estricta de plantillas Angular. | `tsconfig.json` (`strict: true`), `angularCompilerOptions.strictTemplates: true` |
| RNF-09 | El *polling* de estado de un *job* no debe extenderse indefinidamente; debe tener un tiempo máximo de espera. | `reports-export-page.component.ts`, `POLL_TIMEOUT_MS = 5 * 60 * 1000` |
| RNF-10 | Las rutas de presentación deben cargarse de forma perezosa (*lazy loading*) por componente. | `app.routes.ts`, uso de `loadComponent` en las 3 rutas |

## 4. Reglas de negocio

| ID | Regla | Evidencia |
|---|---|---|
| RN-01 | El umbral por defecto para considerar un control como "brecha" es 60% (`threshold: 60`). | `api-reporting.repository.ts`, parámetro `threshold: '60'`; `reporting.types.ts`, `GapAnalytics.threshold` |
| RN-02 | La banda de madurez de un dominio ISO se determina por rangos de puntaje: ≥80 "Optimizado", ≥60 "Definido", ≥40 "Gestionado", ≥20 "Inicial", &lt;20 "Inexistente". | `reporting-diagnostic.mapper.ts::bandLabel`, replicada también en `mock-reporting.repository.ts::bandLabel` |
| RN-03 | El formato de página por defecto para la generación de reportes es `A4`, si no se especifica explícitamente. | `api-reporting.repository.ts`, `pageFormat: req.pageFormat ?? 'A4'` (en ambos métodos de creación de *job*) |
| RN-04 | Si al crear un *job* de reporte simple no se recibe `organizationId`, el sistema debe obtenerlo consultando primero los metadatos de la evaluación (`GET /assessments/{id}`). | `api-reporting.repository.ts::createReportJob` |
| RN-05 | El tipo de reporte `EXCEL_INSTRUMENT_EXPORT` es la única excepción a la convención de nombres "termina en `_XLSX`" para tipos Excel; el sistema debe tratarlo explícitamente como Excel al resolver la extensión de archivo. | `report-filename.util.ts::isExcelReportType` |
| RN-06 | El nombre de archivo de reserva depende del prefijo del tipo de reporte: `COMPARATIVE_DIAGNOSTIC_XLSX` → `portada-comparativo-{jobId}`; otros `COMPARATIVE_*` → `comparativo-{jobId}`; `GAP_LIST_*` → `brechas-{assessmentId}`; cualquier otro (diagnóstico completo, instrumento) → `portada-{assessmentId}`. | `report-filename.util.ts::fallbackReportFilename` |
| RN-07 | Aun si el backend informa un nombre de archivo por `Content-Disposition`, la extensión final siempre se fuerza según el tipo de reporte solicitado (nunca se confía en la extensión que traiga el encabezado). | `report-filename.util.ts::resolveReportFilename` |
| RN-08 | Un *job* de reporte pasa por el ciclo de estados `PENDING → RUNNING → COMPLETED` o `PENDING → RUNNING → FAILED`; `CANCELLED` es tratado como estado terminal equivalente a fallo en la interfaz. | `reporting.types.ts::ReportJobStatus`, `docs/DIAGRAMAS.md`, `reports-export-page.component.ts::pollOnce` |
| RN-09 | Si la evaluación activa (`active_assessment_id`) no existe en `localStorage`, no se debe intentar cargar ningún tablero; se ofrece únicamente el modo demo. | `reports-home-page.component.ts` |
| RN-10 | El campo `outputFileId` de un *job* es puramente informativo (copia archivada en evidencias) y **no debe usarse** como fuente de descarga; la descarga siempre pasa por `GET /reports/jobs/{jobId}/download`. | Comentario explícito en `reporting.types.ts`: *"Informativo: copia archivada en evidence (S2S). No usar para descargar."* |
| RN-11 | Una respuesta de descarga cuyo `Content-Type` contenga `json` debe tratarse como error, no como archivo binario, independientemente del código de estado HTTP. | `report-download.helper.ts::mapReportDownloadResponse` |

## 5. Casos de uso

### CU-01 Ver estado de evaluación activa e ingresar al módulo de reportes

**Actor:** Usuario autenticado.
**Flujo principal:**
1. El usuario navega a `/reports` (directo o vía iframe del shell).
2. El sistema lee `active_assessment_id` de `localStorage`.
3. Si existe, muestra el id y un botón "Abrir diagnóstico".
4. Si no existe, muestra un mensaje informativo y un botón "Ver demo (mock-assessment-1)".

**Evidencia:** `reports-home-page.component.ts`.

### CU-02 Consultar el diagnóstico consolidado de una evaluación

**Actor:** Usuario autenticado con evaluación (real o demo).
**Precondición:** Se conoce el `assessmentId` (parámetro de ruta).
**Flujo principal:**
1. El sistema solicita en paralelo el tablero de diagnóstico (`GET .../diagnostic/dashboard`) y las brechas (`GET .../gaps?threshold=60`) a `ms_assessment`, y los metadatos de la evaluación (`GET /assessments/{id}`).
2. Si la consulta de metadatos falla, el sistema continúa con un valor de reserva ("Evaluación MSPI", sin organización) en vez de bloquear la carga del tablero.
3. El sistema normaliza las tres respuestas en un único modelo `DiagnosticDashboard` mediante `mapToReportsDashboard`.
4. El sistema renderiza tarjetas resumen, tabla de dominios ISO, barras PHVA, tabla de madurez, lista NIST y tabla de brechas.

**Flujo alternativo:** Si la carga falla, se muestra el mensaje de error capturado (`error()`), en vez del tablero.

**Evidencia:** `diagnostic-dashboard-page.component.ts`, `api-reporting.repository.ts::getDiagnosticDashboard`, `reporting-diagnostic.mapper.ts`.

### CU-03 Generar y descargar un reporte

**Actor:** Usuario autenticado con evaluación activa.
**Precondición:** El usuario está en `/assessments/:id/export`.
**Flujo principal:**
1. El usuario selecciona uno de los cuatro tipos de reporte disponibles (botones).
2. El sistema crea el *job* (`POST /reports/jobs`) con `organizationId`, `reportType` y `pageFormat: 'A4'` por defecto.
3. El sistema inicia el *polling* cada 2.5 segundos, consultando `GET /reports/jobs/{jobId}`.
4. Mientras el estado sea `RUNNING`, se actualiza el mensaje con el porcentaje de progreso.
5. Al llegar a `COMPLETED`, el sistema detiene el *polling* y dispara automáticamente la descarga (una sola vez, controlado por la bandera `autoDownloaded`).
6. El sistema descarga el binario (`GET /reports/jobs/{jobId}/download`), resuelve su nombre de archivo y lo guarda mediante un enlace `<a download>` generado dinámicamente.

**Flujos alternativos:**
- **Job falla (`FAILED`/`CANCELLED`):** se detiene el *polling* y se muestra `job.errorMessage` o un mensaje genérico.
- **Tiempo de espera agotado (&gt;5 min):** se detiene el *polling*, se marca error y se invita a reintentar.
- **Descarga con error JSON disfrazado de blob:** se extrae el mensaje del cuerpo JSON y se muestra como error, sin intentar guardar un archivo corrupto.
- **Descarga manual repetida:** el usuario puede volver a pulsar "Descargar archivo" mientras el *job* siga `COMPLETED`, sin crear un nuevo *job*.

**Evidencia:** `reports-export-page.component.ts`, `api-reporting.repository.ts::createReportJob/getReportJob/downloadReport`, `report-download.helper.ts`, `report-download.service.ts`.

### CU-04 Sincronizar sesión desde el shell

**Actor:** `mf_shell` (sistema).
**Flujo principal:**
1. Al iniciar, `mf_reports` (si está embebido en un iframe) solicita la sesión al padre enviando un mensaje `MSPI_AUTH_REQUEST` a cada origen permitido.
2. El shell responde con un mensaje `MSPI_AUTH_SESSION` conteniendo el payload de sesión serializado.
3. `mf_reports` valida el origen del mensaje contra la lista blanca, valida que la sesión no esté expirada, la guarda en `localStorage` y notifica a `AuthSessionService` para recargar su estado reactivo.

**Evidencia:** `auth-parent-bridge.ts`, `app.component.ts`, `auth-session.service.ts`.

## 6. Modelo de datos observado (resumen)

El tipo central del dominio es `DiagnosticDashboard` (`reporting.types.ts`), compuesto por:

- `iso: IsoAnalytics` — dominios ISO con puntaje, banda y conteo de controles, más promedio y banda global.
- `phva: PhvaAnalytics` — componentes PLAN/DO/CHECK/ACT con avance capado (`cappedL`) y total.
- `maturity: MaturityAnalytics` — nivel alcanzado, nivel global numérico, criticidad (`SUFICIENTE`/`INTERMEDIO`/`CRITICO`) y matriz de requisitos.
- `nist: NistAnalytics` — funciones NIST CSF con puntaje promedio.
- `gaps: GapAnalytics` — umbral aplicado y listado de controles por debajo de él.

El tipo `ReportJob` modela el ciclo de vida de un trabajo de generación de reporte, con timestamps opcionales (`requestedAt`, `startedAt`, `finishedAt`), progreso (`progressPct`) y mensaje de error (`errorMessage`).

## 7. Trazabilidad con la documentación preexistente

Los requerimientos y reglas anteriores son consistentes con lo declarado en `docs/DESCRIPCION.md`, `docs/API-INTEGRACION.md` y `docs/FLUJOS.md` del propio repositorio, que ya identificaban: los dos backends consumidos (`ms_reporting`, `ms_assessment`), el ciclo de estados del *job*, la fuerza de extensión `.xlsx` para `EXCEL_INSTRUMENT_EXPORT`, y el error conocido de `CorrectResponse` en fallos de `ms_reporting`. Este documento amplía esa base con el detalle de requisitos, actores y casos de uso que la documentación original no formalizaba explícitamente.
