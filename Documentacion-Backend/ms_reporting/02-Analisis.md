# ms_reporting — Análisis

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_reporting` |
| Fecha del documento | 2026-08-19 |
| Alcance | Requerimientos funcionales/no funcionales, reglas de negocio y casos de uso del microservicio `ms_reporting` |

---

## 1. Actores

| Actor | Descripción |
|---|---|
| **Usuario autenticado** | Cualquier usuario con JWT válido emitido por Keycloak (realm `iam`); `SecurityConfig` no discrimina por rol de negocio para `/reports/**`, solo exige autenticación (`.requestMatchers("/reports/**").authenticated()`) |
| **ms_assessment** | Microservicio interno que expone `report-export-bundle` (datos consolidados de una evaluación) y `gaps` (lista de brechas) |
| **ms_evidence** | Microservicio interno que recibe el artefacto generado (`report-outputs`) y sirve la descarga cuando no hay caché local |
| **ms_catalog** | Microservicio interno con el catálogo de escalas publicadas; su gateway existe pero no es invocado en el flujo actual |
| **Sistema (job asíncrono)** | El propio `ProcessReportJobUseCase`, ejecutado en un hilo del pool `reportJobExecutor`, actúa como actor interno que transiciona el estado del job sin intervención humana |

## 2. Requerimientos funcionales

| ID | Requerimiento | Evidencia |
|---|---|---|
| RF-01 | Crear un job de generación de reporte estándar para una evaluación, devolviendo `202 Accepted` con el job en `PENDING` | `ReportJobApi.create`, `CreateReportJobUseCase` |
| RF-02 | Validar campos obligatorios al crear el job: `assessmentId`, `organizationId`, `reportType`, `requestedBy` | `CreateReportJobUseCase.validate` |
| RF-03 | Restringir `pageFormat` a `A4` o `LETTER` cuando el tipo de reporte es `FULL_DIAGNOSTIC_PDF` | `CreateReportJobUseCase.validate` |
| RF-04 | Consultar el estado y metadatos de un job por su `jobId` | `GetReportJobUseCase`, `GET /reports/jobs/{jobId}` |
| RF-05 | Procesar el job de forma asíncrona inmediatamente después de crearlo, sin bloquear la respuesta HTTP | `ReportJobApi.create`: `CompletableFuture.runAsync(...)` tras la creación |
| RF-06 | Generar un PDF de diagnóstico completo (hoja PORTADA) rellenando la plantilla oficial y convirtiéndola con LibreOffice | `ProcessReportJobUseCase.generateFullDiagnosticPdf`, `MspiPortadaTemplateFiller`, `LibreOfficePdfConverter` |
| RF-07 | Generar un Excel con la hoja PORTADA rellena (mismo contenido que el PDF, sin conversión) | `ProcessReportJobUseCase.generateExcel`, `ReportDocumentService.buildPortadaWorkbook` |
| RF-08 | Generar un PDF con la lista priorizada de brechas de una evaluación | `ProcessReportJobUseCase.generateGapPdf`, `ReportDocumentService.buildGapListPdf` |
| RF-09 | Generar un Excel con la lista de brechas (columnas: Dominio, Control, Score, Brecha, Recomendación, Área) | `ProcessReportJobUseCase.generateGapXlsx`, `ReportDocumentService.buildGapListXlsx` |
| RF-10 | Crear un job comparativo multi-evaluación, validando mínimo 2 evaluaciones y que todas pertenezcan a la misma organización | `CreateComparativeReportJobUseCase` |
| RF-11 | Generar un PDF comparativo con una tabla de efectividad por dominio por cada evaluación incluida | `ReportDocumentService.buildComparativePdf` |
| RF-12 | Generar un Excel comparativo (usa la hoja PORTADA de la **primera** evaluación de la lista, no una combinación real de todas) | `ProcessReportJobUseCase.generateComparative` (rama `COMPARATIVE_DIAGNOSTIC_XLSX`: `bundles.get(0)`) |
| RF-13 | Registrar cada evaluación vinculada a un job comparativo con su rol (`PRIMARY`/`COMPARISON`) y orden de despliegue | `CreateComparativeReportJobUseCase`, tabla `report_job_assessment` |
| RF-14 | Actualizar el progreso del job durante el procesamiento (`10%` al iniciar, `90%` tras generar el archivo, `100%` al completar) | `ProcessReportJobUseCase.execute` |
| RF-15 | Marcar el job como `FAILED` con `errorMessage` ante cualquier excepción durante la generación, sin propagar el error al hilo asíncrono | `ProcessReportJobUseCase.execute` (captura `Throwable`) |
| RF-16 | Guardar el artefacto generado en una caché local en disco del contenedor, indexada por `jobId` | `FileSystemReportOutputStorage` |
| RF-17 | Archivar el artefacto en `ms_evidence` como evidencia `REPORT_OUTPUT`, de forma no bloqueante (best effort) | `ReportOutputEvidenceArchiver` |
| RF-18 | Permitir deshabilitar el archivado a `ms_evidence` por configuración (`REPORT_ARCHIVE_TO_EVIDENCE=false`) | `ReportOutputStorageProperties.archiveToEvidence`, `UseCaseConfig.reportOutputEvidenceArchiver` |
| RF-19 | Descargar el artefacto solo si el job está `COMPLETED`; en otro estado, rechazar con error de regla de negocio | `DownloadReportJobUseCase.execute` |
| RF-20 | Al descargar, preferir la caché local; si no existe, hacer streaming desde `ms_evidence` usando el `outputFileId` | `DownloadReportJobUseCase.execute` |
| RF-21 | Devolver el archivo descargado con `Content-Disposition: attachment` y el nombre/MIME correctos según el tipo de reporte | `ReportJobApi.download`, `ReportArtifactDescriptor` |
| RF-22 | Resolver la identidad del solicitante (`requestedBy`) a partir del `sub` (subject) del JWT | `JwtSupport.userId` |

## 3. Requerimientos no funcionales

| ID | Requerimiento | Evidencia |
|---|---|---|
| RNF-01 | Todas las rutas de negocio (`/reports/**`) requieren autenticación JWT Bearer; solo `/actuator/health`, `/actuator/info` y `/error` son públicas | `SecurityConfig.securityFilterChain` |
| RNF-02 | Las llamadas salientes a otros microservicios internos deben incluir la cabecera `X-Internal-Api-Key`, compartida y verificada por el microservicio receptor | `RestConsumerConfig`, README |
| RNF-03 | El servicio no ejecuta DDL/DML automático al arrancar (`spring.sql.init.mode: never`, `hibernate.ddl-auto: none`) | `application.yaml` |
| RNF-04 | El procesamiento de jobs debe ejecutarse en un pool de hilos acotado y nombrado, distinto del pool HTTP de Tomcat, para no bloquear peticiones entrantes | `ReportJobAsyncConfig` (`reportJobExecutor`, core 2 / max 4 / cola 25) |
| RNF-05 | La conversión PDF debe tener un tiempo máximo de espera y no bloquearse por pipes sin drenar ni perfil LO compartido | `CONVERSION_TIMEOUT_SECONDS = 120L`; `Redirect.DISCARD` + `-env:UserInstallation` por conversión |
| RNF-06 | El servicio debe exponer *health checks* HTTP consumibles por Docker/orquestador | `/actuator/health`, `/actuator/info`, `deployment/Dockerfile` `HEALTHCHECK` |
| RNF-07 | El artefacto de compilación debe generarse sin ejecutar pruebas en la etapa de build de la imagen Docker (`-x test`), delegando la validación al pipeline de CI/pruebas locales | `deployment/Dockerfile` |
| RNF-08 | Cobertura de pruebas mínima del 80% de instrucciones por módulo (regla configurada, ver `05-Pruebas.md` para el estado real) | `main.gradle`: `jacocoTestCoverageVerification` |
| RNF-09 | Encabezados de seguridad HTTP: `X-Frame-Options: DENY`, HSTS (`max-age=31536000`, `includeSubDomains`, `preload`) | `SecurityConfig.securityFilterChain` |
| RNF-10 | Trazabilidad de peticiones mediante un identificador de traza propagado en errores | `TraceIdFilter`, `GlobalExceptionHandler.getTraceId` |
| RNF-11 | El contenedor de ejecución corre como usuario no root (`mspi`) | `deployment/Dockerfile` |
| RNF-12 | El heap de la JVM se limita al 75% de la memoria asignada al contenedor | `deployment/Dockerfile`: `JAVA_OPTS`, `-XX:MaxRAMPercentage=75.0` |

## 4. Reglas de negocio (extraídas de `domain/usecase`)

| # | Regla | Ubicación |
|---|---|---|
| RN-01 | `assessmentId`, `organizationId`, `reportType` y `requestedBy` son obligatorios al crear un job estándar | `CreateReportJobUseCase.validate` |
| RN-02 | Si `reportType == FULL_DIAGNOSTIC_PDF` y se informa `pageFormat`, este debe ser `A4` o `LETTER` (comparación *case-insensitive*); si se omite, no se valida (se resuelve un valor por defecto `A4` en la capa de persistencia) | `CreateReportJobUseCase.validate`, `ReportingJpaAdapter.createJob` |
| RN-03 | Un job en estado `COMPLETED` o `CANCELLED` no se vuelve a procesar si `ProcessReportJobUseCase.execute` es invocado nuevamente sobre el mismo `jobId` (idempotencia parcial) | `ProcessReportJobUseCase.execute` |
| RN-04 | El diagnóstico completo (PDF y Excel) contiene **únicamente** la hoja PORTADA de la plantilla oficial; todas las demás hojas del libro se eliminan antes de servir el archivo | `MspiPortadaTemplateFiller.retainOnlyPortadaSheet` |
| RN-05 (`#116`) | Un job comparativo requiere al menos 2 evaluaciones distintas (la primaria más al menos una de comparación, deduplicadas por `Set<UUID>`) | `CreateComparativeReportJobUseCase.execute` |
| RN-06 (`#116`) | Todas las evaluaciones de un job comparativo deben pertenecer a la misma `organizationId` que la solicitud; se valida contra el campo `organizationId` embebido en el *bundle* de cada evaluación | `CreateComparativeReportJobUseCase.execute` |
| RN-07 | Si no se especifica `reportType` en un job comparativo, se asume `COMPARATIVE_DIAGNOSTIC_PDF` por defecto | `CreateComparativeReportJobUseCase.execute`, `ComparativeReportJobApi.create` |
| RN-08 | La primera evaluación agregada (`primaryAssessmentId`) recibe el rol `PRIMARY`; el resto recibe `COMPARISON`, con `sortOrder` incremental en el orden de iteración del conjunto | `CreateComparativeReportJobUseCase.execute` |
| RN-09 | Un reporte solo puede descargarse si su estado es `COMPLETED`; en `PENDING`, `RUNNING`, `FAILED` o `CANCELLED` se rechaza con `BusinessRulesOnFieldsException` | `DownloadReportJobUseCase.execute` |
| RN-10 | El nombre de archivo y el tipo MIME de cada artefacto se derivan exclusivamente de `ReportArtifactDescriptor`, única fuente de verdad de nomenclatura (evita duplicación/discrepancia entre generación y descarga) | `ReportArtifactDescriptor` |
| RN-11 | Si la conversión a PDF está deshabilitada por configuración (`REPORT_PDF_CONVERSION_ENABLED=false`), cualquier job `FULL_DIAGNOSTIC_PDF` falla explícitamente en vez de degradarse silenciosamente | `LibreOfficePdfConverter.convertXlsxToPdf` |
| RN-12 | El fallo al archivar en `ms_evidence` no cambia el resultado del job: el job se marca `COMPLETED` igualmente y `outputFileId` queda `null` | `ProcessReportJobUseCase.execute`, `ReportOutputEvidenceArchiver.archive` |
| RN-13 | El avance PORTADA PHVA se escribe por **cláusula** (`phva.clauses[]`: `clauseCode` C.4–C.10, `score`, `weight` 0.14/0.16): celda F = `(score/100)*weight`; total = suma F30:F36 | `MspiPortadaTemplateFiller.fillPhva` |
| RN-14 | Las celdas de la hoja PORTADA que no tienen un renglón mapeado para el código de dominio/función recibido se ignoran silenciosamente (no se lanza error si el *bundle* trae un dominio no contemplado en `DOMAIN_ROWS`) | `MspiPortadaTemplateFiller.fillDomains`/`fillNist` |

## 5. Casos de uso

### CU-01 Crear job de reporte estándar

- **Actor**: Usuario autenticado.
- **Precondición**: JWT válido; evaluación existente en `ms_assessment` (no se valida su existencia en la creación, solo al procesar).
- **Flujo principal**: `POST /reports/jobs` → `CreateReportJobUseCase.execute` valida campos → `ReportingJpaAdapter.createJob` inserta `report_generation_job` con `status=PENDING`, `progress_pct=0` → API dispara `CompletableFuture.runAsync(() -> processReportJobUseCase.execute(jobId), reportJobExecutor)` → responde `202 Accepted` con el job recién creado.
- **Postcondición**: Job persistido en `PENDING`; procesamiento en curso en segundo plano, sin garantía de sincronía con la respuesta HTTP.

### CU-02 Procesar job (generación del documento)

- **Actor**: Sistema (hilo `report-job-*`).
- **Flujo principal**: `ProcessReportJobUseCase.execute(jobId)` → carga el job → si no está `COMPLETED`/`CANCELLED`, transiciona a `RUNNING` (`progressPct=10`) → según `ReportType`, obtiene el *bundle* de `ms_assessment` (`fetchReportExportBundle` o `fetchGaps`) → invoca el generador correspondiente (`ReportDocumentService`) → guarda el binario en `FileSystemReportOutputStorage` (`progressPct=90`) → intenta archivar en `ms_evidence` (best effort) → marca `COMPLETED` (`progressPct=100`, `finishedAt`).
- **Flujo alterno (error)**: cualquier `Throwable` durante generación → job marcado `FAILED` con `errorMessage` y `finishedAt`; no se reintenta automáticamente.

### CU-03 Consultar estado de job

- **Actor**: Usuario autenticado.
- **Flujo principal**: `GET /reports/jobs/{jobId}` → `GetReportJobUseCase.execute` → `ResourceNotFoundException` (404) si no existe → respuesta con estado, `progressPct`, `outputFileId`, `errorMessage`.

### CU-04 Descargar reporte generado

- **Actor**: Usuario autenticado.
- **Precondición**: Job en `COMPLETED`.
- **Flujo principal**: `GET /reports/jobs/{jobId}/download` → `DownloadReportJobUseCase.execute` → intenta `FileSystemReportOutputStorage.findByJobId` (caché local) → si no existe, usa `outputFileId` para hacer streaming desde `ms_evidence` (`GET /internal/files/{fileId}/download`) → si tampoco hay `outputFileId`, `ResourceNotFoundException`.
- **Flujo alterno**: job no `COMPLETED` → `BusinessRulesOnFieldsException` (400).

### CU-05 Crear y procesar job comparativo

- **Actor**: Usuario autenticado.
- **Flujo principal**: `POST /reports/comparative/jobs` → `CreateComparativeReportJobUseCase.execute` valida cantidad mínima y organización única entre evaluaciones (consultando el *bundle* de cada una contra `ms_assessment`) → crea el job base (`CreateReportJobCommand`) → registra cada `ReportJobAssessmentLink` (`PRIMARY`/`COMPARISON`) → API dispara el mismo `ProcessReportJobUseCase` en segundo plano.
- **Diferencia con CU-02**: `ProcessReportJobUseCase.generateComparative` recupera la lista de `assessmentId` vinculados (`findAssessmentIdsByJobId`) y agrega el *bundle* de cada uno antes de generar.

## 6. Hallazgos de análisis (brechas y observaciones)

- **`DIAGNOSTIC_WIDGET_PNG` y `DIAGNOSTIC_WIDGET_PDF`** existen en el enum `ReportType` (y en la tabla del README) pero no tienen rama en el `switch` de `ProcessReportJobUseCase.generate`; si un cliente los solicitara, `CreateReportJobUseCase` los aceptaría (no hay validación de tipo soportado en creación) y el job fallaría en `RUNNING` con `IllegalStateException: Tipo de reporte no soportado`, quedando en `FAILED`. Es una funcionalidad anunciada pero no implementada.
- **`CatalogGateway`** (puerto de dominio) está definido y su adaptador (`CatalogGatewayAdapter`) existe en `rest-consumer`, pero **no se invoca** desde ningún caso de uso actual (`ProcessReportJobUseCase` no llama `catalogGateway.fetchPublishedScale()` en ninguna rama). El README lo documenta como dependencia ("hoja Escala en Excel"), pero esa hoja fue eliminada del alcance real (solo se conserva PORTADA). Gateway sin consumidor activo: candidato a eliminar o a completar en una futura versión de la plantilla.
- **Excel comparativo (`COMPARATIVE_DIAGNOSTIC_XLSX`)** no combina las evaluaciones: `ProcessReportJobUseCase.generateComparative` usa `bundles.get(0)` (solo la primera evaluación del listado) para rellenar la plantilla PORTADA, mientras que el PDF comparativo (`buildComparativePdf`) sí recorre todas. Esto es una limitación funcional real del Excel comparativo frente al PDF comparativo.
- **Umbral de brechas fijo**: `ProcessReportJobUseCase.resolveGaps` invoca `fetchGaps` con `threshold=60` y `isoDomain`/`steward` en `null` de forma *hardcodeada*; no hay manera de que el cliente parametrice el umbral o los filtros de dominio/responsable al solicitar `GAP_LIST_PDF`/`GAP_LIST_XLSX` desde la API pública actual.
- **Seeds desalineados**: `data.sql` / `MER-SEED-REPORTING.sql` aún describen plantillas Jasper / multi-hoja; el motor activo usa `reports/plantilla-portada-2022.xlsx` en classpath (ignorando `storage_path` de BD). Las tablas de plantillas son metadatos descriptivos.
