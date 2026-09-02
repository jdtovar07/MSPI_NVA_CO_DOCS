# ms_reporting — Desarrollo

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_reporting` |
| Fecha del documento | 2026-08-19 |
| Alcance | Implementación real, librerías, patrones y funcionalidades concretas del microservicio `ms_reporting` |

---

## 1. Convenciones y patrones de implementación

- **Casos de uso como POJOs planos** (`@RequiredArgsConstructor` de Lombok, sin anotaciones de Spring) instanciados como `@Bean` en `UseCaseConfig` — el mismo patrón usado en el resto de microservicios MSPI para mantener `domain/usecase` libre de dependencias del framework.
- **Puertos (`gateway`) definidos en `domain/model`**, implementados en los módulos de infraestructura correspondientes (`jpa-repository` para persistencia, `rest-consumer` para HTTP saliente, `app-service` para la caché de archivos). Todos los adaptadores usan `@Component` + inyección por constructor (`@RequiredArgsConstructor` o constructor explícito).
- **DTOs de entrada/salida separados del modelo de dominio**: `CreateReportJobRequest`/`ReportJobResponse` (api-rest) se mapean a/desde `CreateReportJobCommand`/`ReportGenerationJob` (model) mediante `ReportJobApiMapper`, evitando que Jackson serialice directamente el modelo de dominio.
- **Registro único de nombres/MIME de artefactos**: `ReportArtifactDescriptor` (clase `final`, package-private) centraliza la construcción de `filename()` y `contentType()` a partir de `ReportType`, usada tanto en la generación (`ProcessReportJobUseCase`) como en la descarga (`DownloadReportJobUseCase`) — evita que ambos flujos calculen el nombre de archivo de forma independiente y diverjan.
- **Registro de excepciones de dominio en `common`**: `ResourceNotFoundException` (404), `BusinessRulesOnFieldsException` (400) y `DomainException` (500 genérico) se traducen centralizadamente en `GlobalExceptionHandler` (`@RestControllerAdvice`) al formato `ErrorResponse` estándar MSPI, con `traceId` tomado de MDC (`TraceIdFilter`).
- **`record` de Java** usado para resultados internos inmutables sin necesidad de Lombok: `GeneratedFile` (privado en `ProcessReportJobUseCase`), `Result` (público en `DownloadReportJobUseCase`), `StoredReportOutput` (en el gateway `ReportOutputStorageGateway`).
- **Extracción defensiva de mapas anidados**: tanto `ReportDocumentService` como `MspiPortadaTemplateFiller` implementan helpers privados repetidos (`map(...)`, `list(...)`, `str(...)`, `num(...)`) para navegar el `Map<String,Object>` deserializado del JSON del *bundle* de `ms_assessment` sin *casts* inseguros ni `NullPointerException`, devolviendo `Map.of()`/`List.of()` cuando una clave falta — patrón duplicado entre ambas clases (candidato a refactor de una utilidad común, no realizado).

## 2. Funcionalidad: generación del diagnóstico PORTADA (PDF/Excel)

Es el flujo más elaborado del microservicio y el que justifica la mayoría de las dependencias de terceros.

### 2.1 Relleno de plantilla (`MspiPortadaTemplateFiller`)

- Carga `reports/plantilla-referencia-mspi.xlsx` desde el **classpath** del módulo `domain/usecase` (`src/main/resources/reports/plantilla-referencia-mspi.xlsx`), no desde una ruta configurable ni desde la BD, con Apache POI (`XSSFWorkbook`).
- El mapeo celda↔dato usa **coordenadas fijas (fila/columna 1-based)** codificadas como constantes Java, no un `cell_map_json` dinámico pese a que la tabla `excel_sheet_mapping` del esquema lo contempla:
  - `DOMAIN_ROWS`: dominios ISO `A.5`..`A.18` mapeados a filas 19–32 (`14 + i` para `i` en `[5,18]`).
  - `PHVA_ROWS`: `PLAN`→39, `DO`→40, `CHECK`→41, `ACT`→42.
  - `MATURITY_ROWS`: niveles 1–5 mapeados a filas 57/59/61/63/65.
  - `NIST_CHART_ROWS` (gráfico radar): `ID`→95, `DE`→96, `RS`→97, `RC`→98, `PR`→99; y `nistTableRow` (tabla de metas) con un mapeo distinto por función: `DE`→72, `ID`→73, `PR`→74, `RC`→75, `RS`→76.
- Normaliza fracciones PHVA a rango `[0,1]` (`setFraction`, RN-13 en `02-Analisis.md`) y bandas/categorías a mayúsculas (`normalizeBandLabel`, `normalizeCategoria` — esta última además reemplaza `Í`→`I`, cuidando compatibilidad de fuente/estilo de la celda de la plantilla).
- Al escribir en una celda nueva (`cell(...)`), copia el estilo de la celda vecina a la izquierda (`neighbor.getCellStyle()`) para no perder el formato condicional/color de la plantilla en celdas que originalmente estaban vacías.
- **Elimina todas las hojas excepto PORTADA** (`retainOnlyPortadaSheet`, recorrido en orden descendente de índice para no invalidar índices al remover) — es la operación que garantiza el requerimiento RN-04.

### 2.2 Conversión a PDF (`LibreOfficePdfConverter`)

- Resuelve el ejecutable de LibreOffice en orden de prioridad: variable de entorno `LIBREOFFICE_PATH` → `soffice` (si está en `PATH`) → rutas típicas de instalación en Windows (`C:\Program Files\LibreOffice\program\soffice.exe` y su variante `(x86)`).
- Ejecuta `soffice --headless --nologo --nofirststartwizard --convert-to pdf --outdir <tmp> <archivo.xlsx>` con `ProcessBuilder`, redirigiendo stderr a stdout, con **timeout de 120 segundos** (`process.waitFor(120, TimeUnit.SECONDS)`); si expira, destruye el proceso forzosamente y lanza `IOException`.
- Trabaja siempre sobre un **directorio temporal único por conversión** (`Files.createTempDirectory("mspi-portada-pdf-")`), que se limpia en un bloque `finally` (`deleteQuietly`, recorrido de árbol con `SimpleFileVisitor`) — evita acumulación de archivos temporales en el contenedor ante generaciones repetidas.
- `isEnabled()` lee `REPORT_PDF_CONVERSION_ENABLED` en cada llamada (no cachea el valor), permitiendo en teoría cambiar el comportamiento sin reiniciar si la variable de entorno se modificara dinámicamente (aunque en un contenedor Docker las variables de entorno son fijas por el ciclo de vida del proceso, por lo que en la práctica equivale a una constante de arranque).

### 2.3 Reportes de brechas y comparativo (`ReportDocumentService`, OpenPDF)

- Usa **OpenPDF** (`com.lowagie.text.*`), no iText propietario ni PDFBox — biblioteca con licencia LGPL/MPL, elegida probablemente para evitar las restricciones de licenciamiento de iText 5+.
- Tres estilos de fuente predefinidos como constantes estáticas (`TITLE` 16pt bold, `H2` 12pt bold, `BODY` 10pt regular), reutilizados en todos los documentos generados con OpenPDF.
- `buildGapListPdf`/`buildGapListXlsx`: iteran `gaps.items[]` (cada ítem con `isoDomainCode`, `controlCode`, `currentScore`, `gapTo100`, `recommendation`, `areaName`) — en PDF como párrafos de texto plano concatenado, en Excel como filas de hoja `Brechas` con encabezado fijo.
- `buildComparativePdf`: para cada *bundle* de evaluación agregada, imprime un encabezado (`fecha — organización`) y una tabla de 4 columnas (`Dominio | Score | Meta | Banda`) generada con `PdfPTable`, ordenando los dominios por `displayPosition` antes de renderizar.

## 3. Funcionalidad: ciclo de vida del job y concurrencia

- `ReportJobAsyncConfig` define un `ThreadPoolTaskExecutor` nombrado `reportJobExecutor` (bean `@Qualifier`), inyectado explícitamente en los controladores (`ReportJobApi`, `ComparativeReportJobApi`) en lugar de usar `@Async` declarativo sobre el caso de uso — decisión que mantiene `domain/usecase` libre de anotaciones de Spring (`@Async` requiere que el bean sea un proxy Spring).
- El controlador crea el job de forma síncrona (para poder devolver el `id` real en el `202 Accepted`) y **luego** lanza `CompletableFuture.runAsync(() -> processReportJobUseCase.execute(job.getId()), reportJobExecutor)`, descartando el `CompletableFuture` resultante (no se encadena `.exceptionally()` ni se registra su fallo fuera de lo que ya maneja `ProcessReportJobUseCase.execute` internamente con su propio `try/catch(Throwable)`).
- `ProcessReportJobUseCase.execute` es **idempotente en los estados terminales**: si el job ya está `COMPLETED` o `CANCELLED`, retorna sin hacer nada — protección básica contra ejecuciones duplicadas del mismo `jobId` (aunque no hay un `SELECT ... FOR UPDATE` ni bloqueo optimista explícito a nivel de fila, por lo que dos invocaciones concurrentes sobre el mismo job `PENDING` podrían, en teoría, procesar el mismo job dos veces; no se identificó protección adicional en el código).

## 4. Funcionalidad: descarga con doble fuente

`DownloadReportJobUseCase` implementa un patrón de **caché-con-respaldo remoto**:

1. Verifica `status == COMPLETED` (si no, `BusinessRulesOnFieldsException`).
2. Intenta `reportOutputStorageGateway.findByJobId(jobId)` (lectura de disco local, `FileSystemReportOutputStorage`, que persiste `content.bin` + `meta.properties` con `filename`/`contentType` por cada `jobId` en un subdirectorio propio).
3. Si no hay caché local, usa `job.getOutputFileId()` para pedir el binario a `ms_evidence` (`GET /internal/files/{fileId}/download`), envolviendo el `byte[]` de respuesta en un `ByteArrayInputStream` — el nombre/tipo en este camino se recalculan con `ReportArtifactDescriptor` (no viajan desde `ms_evidence`).
4. Si tampoco hay `outputFileId`, `ResourceNotFoundException`.

El controlador (`ReportJobApi.download`) envuelve el `InputStream` resultante en `InputStreamResource` de Spring, fijando `Content-Type` desde el resultado y `Content-Disposition: attachment; filename="..."`.

## 5. Seguridad implementada

- **`SecurityConfig`**: `SessionCreationPolicy.STATELESS`, CSRF deshabilitado (API sin estado, sin cookies de sesión), `X-Frame-Options: DENY`, HSTS con `preload`. Resource Server OAuth2 con `JwtDecoder` que soporta **JWK Set URI distinto del issuer** (`JWT_JWK_SET_URI` opcional, útil en despliegues Docker donde el *issuer* visible por el navegador —`localhost`— difiere del hostname interno de Keycloak en la red del contenedor).
- **Roles**: `extractRealmRoles` lee `realm_access.roles` del JWT y los mapea a `ROLE_<rol>`; todo usuario autenticado recibe además `ROLE_USER` fijo. `ms_reporting` **no aplica `@PreAuthorize`/restricciones por rol** en ningún controlador — el control de acceso fino (p. ej. "solo Evaluador puede generar diagnóstico") no está implementado a nivel de `ms_reporting`, solo la autenticación genérica.
- **`JwtSupport.userId`**: extrae el `sub` del JWT como `UUID`; si el subject no es un UUID válido o el JWT es nulo, retorna `null` silenciosamente (sin lanzar excepción) — el `requestedBy` del job podría quedar `null` en un escenario anómalo de JWT mal formado, lo cual violaría la regla RN-01 (`requestedBy` obligatorio) y provocaría `BusinessRulesOnFieldsException` en la validación del caso de uso; es decir, el fallo se detecta, pero un poco más tarde de lo ideal (en negocio, no en el borde de seguridad).
- **`X-Internal-Api-Key`**: agregada como cabecera fija por `RestConsumerConfig` en los tres `RestClient` salientes, solo si la propiedad correspondiente no está vacía.

## 6. Manejo de errores

`GlobalExceptionHandler` centraliza la traducción a HTTP:

| Excepción | HTTP | Código MSPI |
|---|---|---|
| `ResourceNotFoundException` | 404 | `CODE_NOT_FOUND` |
| `BusinessRulesOnFieldsException` | 400 | `CODE_BUSINESS_RULES` |
| `UserAlreadyExistsException` | 409 | `CODE_USER_ALREADY_EXISTS` (heredada del esqueleto común; sin uso funcional en `ms_reporting`) |
| `IamServiceException` | 502 | `CODE_IAM_SERVICE_ERROR` (ídem, sin uso funcional en este microservicio) |
| `MethodArgumentNotValidException` (Bean Validation) | 400 | `CODE_VALIDATION`, uno por campo inválido |
| `DomainException` | 500 | `CODE_INTERNAL_ERROR` genérico |

Los errores producidos **dentro** de la generación asíncrona del documento (fallo de LibreOffice, plantilla no encontrada, bundle incompleto) **no pasan por `GlobalExceptionHandler`** — ocurren en un hilo separado sin contexto HTTP, y se capturan directamente en `ProcessReportJobUseCase.execute` (`catch (Throwable ex)`), guardando `ex.getMessage()` (o el nombre de la clase si el mensaje es `null`) en `job.errorMessage`, consultable después vía `GET /reports/jobs/{jobId}`.

## 7. Dependencias de terceros relevantes (uso real, no solo declaración)

| Librería | Versión | Uso concreto verificado |
|---|---|---|
| `com.github.librepdf:openpdf` | 1.3.39 | `ReportDocumentService`: PDF de brechas y comparativo (`Document`, `PdfWriter`, `PdfPTable`, `Paragraph`, `Font`) |
| `org.apache.poi:poi-ooxml` | 5.2.5 | `MspiPortadaTemplateFiller` (relleno de plantilla) y `ReportDocumentService.buildGapListXlsx` (libro nuevo con `XSSFWorkbook`) |
| Spring `RestClient` | (Spring Framework incluido en Boot 4.0.2) | Los 3 adaptadores de `rest-consumer` |
| `com.infisical:sdk` | 3.0.2 | `InfisicalConfig`/`DBCredentialConfig` (resolución de secretos en producción; sin uso en generación de reportes) |
| Spring Security OAuth2 Resource Server + Jose | (Boot 4.0.2) | Validación de JWT |
| Lombok | 1.18.42 | `@Getter/@Setter/@Builder/@RequiredArgsConstructor` en modelo, comandos y entidades JPA |

No se encontró uso de **JasperReports**, **Thymeleaf**, **FreeMarker** ni ninguna otra plantilla HTML→PDF en el código actual, pese a que los seeds SQL (`data.sql`) referencian archivos `.jrxml` de Jasper — confirmando que ese motor fue reemplazado por el enfoque plantilla-Excel + LibreOffice descrito en este documento (ver hallazgo en `02-Analisis.md`, §6).
