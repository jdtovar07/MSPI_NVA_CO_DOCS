# ms_evidence — Desarrollo

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_evidence` |
| Fecha del documento | 2026-08-19 |
| Alcance | Implementación real, librerías, patrones y funcionalidades concretas de `ms_evidence` |

---

## 1. Convenciones de código observadas

- **Paquete base**: `co.com.mspi`, común a todos los microservicios del repositorio (`ms_iam`, `ms_org`, `ms_evidence`, …), replicando la misma plantilla arquitectónica.
- **Lombok** para reducir boilerplate: `@Data` + `@Builder(toBuilder = true)` en los modelos de dominio mutables (`EvidenceFile`, `AssessmentContext`, `ProcessScopeMetric`, `LiftingDocumentDelivery`), habilitando el patrón *merge/patch* mediante `toBuilder()`. `@RequiredArgsConstructor` en todos los casos de uso y adaptadores para inyección de dependencias por constructor final.
- **Comandos explícitos** (`UploadFileCommand`, `InitLiftingCommand`) en lugar de pasar DTOs de infraestructura al dominio — mantiene el desacoplamiento entre `api-rest` y `usecase`.
- **Resultados como `record`**: `DownloadEvidenceFileUseCase.Result(EvidenceFile file, InputStream content)` — uso de *records* de Java para valores de retorno inmutables de un caso de uso.
- **Mapeo manual** (sin MapStruct) entre capas: `EvidenceApiMapper` (DTO ↔ dominio) y el bloque `toDomain`/`toEntity` dentro de `EvidenceJpaAdapter` (entidad JPA ↔ dominio) — construidos a mano con builders, no generados por anotaciones.
- **Utilidades estáticas con constructor privado**: `EvidenceApiMapper`, `ApiResponseMapper`, `JwtUserIdExtractor` — clases `final` con constructor privado, sin estado.

## 2. Patrones de diseño aplicados

| Patrón | Dónde | Detalle |
|---|---|---|
| Puerto y adaptador (hexagonal) | `EvidencePersistenceGateway` / `EvidenceJpaAdapter`; `FileStorageGateway` / `LocalFileStorageAdapter` | El dominio define la interfaz; la infraestructura la implementa e inyecta vía Spring. |
| Comando (Command) | `UploadFileCommand`, `InitLiftingCommand` | Encapsulan los datos de entrada de un caso de uso, desacoplados del transporte HTTP. |
| Patch/merge inmutable | `UpdateAssessmentContextUseCase`, `UpdateLiftingDeliveryUseCase` | `current.toBuilder().campo(patch.getCampo() != null ? patch.getCampo() : current.getCampo())...build()` — patrón repetido en los tres casos de uso de actualización parcial. |
| Filtro de seguridad encadenado | `InternalApiKeyFilter` antes de `BearerTokenAuthenticationFilter` | `addFilterBefore` en `SecurityConfig`; permite dos mecanismos de autenticación coexistiendo en la misma cadena de filtros según el prefijo de ruta. |
| Fábrica de configuración explícita (sin `@ComponentScan` de casos de uso) | `UseCaseConfig` | Cada caso de uso se declara como `@Bean` explícito recibiendo sus gateways — hace visible el grafo de dependencias en un único archivo. |
| *Property source* dinámico | `InfisicalConfig` (`BeanFactoryPostProcessor`) | Inserta secretos remotos como `MapPropertySource` antes de que el resto del contexto Spring resuelva *placeholders* (`${DB_CREDENTIAL}`, etc.). |

## 3. Funcionalidades concretas implementadas

### 3.1 Carga de evidencia (multipart)

`EvidenceFileApi.upload` recibe `multipart/form-data` con campos `file`, `relationType`, `relationId` (opcional), `contextField` (opcional), extrae el `userId` del JWT (`JwtUserIdExtractor.extract`, parseando el claim `sub` como UUID, con manejo defensivo de formato inválido) y construye un `UploadFileCommand`. Todas las reglas de negocio (MIME, tamaño, coherencia de campos) se aplican dentro de `UploadEvidenceFileUseCase`, no en el controlador — el controlador es una capa fina de adaptación HTTP.

### 3.2 Descarga de evidencia

`EvidenceFileApi.download` (público, JWT) e `InternalFileDownloadApi.download` (interno, API key) comparten exactamente la misma lógica de ensamblado de respuesta: `ResponseEntity` con `Content-Type` real del archivo, `Content-Length` desde el metadato persistido y `Content-Disposition: attachment; filename="..."`. Ambos delegan al mismo `DownloadEvidenceFileUseCase`, evitando duplicar la lógica de negocio entre el canal público y el canal S2S.

### 3.3 Validaciones de negocio centralizadas en el caso de uso

`UploadEvidenceFileUseCase` concentra: conjunto cerrado de tipos MIME (`Set.of(...)`), tamaños máximos diferenciados por tipo de relación (constantes `MAX_FILE_SIZE_BYTES` = 20 MB, `MAX_REPORT_SIZE_BYTES` = 50 MB), y validación cruzada de `relationType`/`contextField`/`relationId`. Cualquier violación lanza `BusinessRulesOnFieldsException` (mapeada uniformemente a HTTP 400 por `GlobalExceptionHandler`).

### 3.4 Inicialización y clonación de levantamiento documental

`InternalLiftingApi` expone `POST /internal/assessments/{assessmentId}/lifting/init` (recibe `InitLiftingRequest` con lista de `documentItemCatalogIds`, validado con `@Valid`/`jakarta.validation`) y `POST /internal/assessments/{sourceAssessmentId}/lifting/clone/{targetAssessmentId}`. `EvidenceJpaAdapter.initLifting`/`.cloneLifting` ejecutan múltiples `save()` dentro de una única transacción (`@Transactional`), garantizando atomicidad entre la creación del contexto, la métrica de alcance y las N filas de entregas.

### 3.5 Integración con `ms_reporting`

`InternalReportOutputApi.uploadReportOutput` reutiliza `UploadEvidenceFileUseCase` fijando `relationType = REPORT_OUTPUT` y `relationId = jobId` (identificador del trabajo de generación de reporte), con un `uploadedBy` por defecto (`UUID` fijo `00000000-0000-0000-0000-000000000001`) cuando `ms_reporting` no provee un usuario explícito — indicando que, para archivos generados por sistema, el autor humano puede no existir.

### 3.6 Trazabilidad y manejo de errores uniforme

- `TraceIdFilter` (en `api-rest/config`) enriquece cada request con `X-Trace-Id` (propagado o generado) y lo expone vía MDC para logging correlacionado.
- `GlobalExceptionHandler` centraliza el mapeo de excepciones de dominio a HTTP: `ResourceNotFoundException` → 404, `BusinessRulesOnFieldsException` → 400, `MethodArgumentNotValidException` (Bean Validation) → 400 con lista de `ErrorDetail` por campo, `DomainException` → 500 (mensaje genérico, sin filtrar detalles internos). El formato de error (`ErrorResponse` con `Meta.traceId`) es consistente con el resto del ecosistema MSPI (`ms_iam`, `ms_org`).
- `ApiResponseMapper` (módulo `common`, compartido) construye tanto `CorrectResponse` (éxito) como `ErrorResponse` (error) con la misma envoltura `Meta` (traceId + timestamp ISO), asegurando un contrato de respuesta homogéneo entre microservicios del sistema.

## 4. Librerías y dependencias por módulo

| Módulo | Dependencias relevantes |
|---|---|
| `app-service` | `spring-boot-starter`, `spring-boot-starter-web`, `spring-boot-starter-security`, `spring-security-oauth2-resource-server`, `spring-security-oauth2-jose`, `jackson-databind`, `com.infisical:sdk:3.0.2`, `spring-boot-devtools` (runtime), `org.postgresql:postgresql` (runtime) |
| `api-rest` | `spring-boot-starter-security`, `spring-boot-starter-webmvc`, `spring-boot-starter-actuator`, `spring-boot-starter-validation`, `spring-security-oauth2-resource-server`/`-jose`, test: `spring-boot-starter-test`, `spring-security-test` |
| `jpa-repository` | `spring-boot-starter-data-jpa`, `org.postgresql:postgresql` (runtime), test: `org.reactivecommons.utils:object-mapper:0.1.0` |
| `usecase` | solo `project(':model')` y `project(':common')` — sin dependencias de framework |
| `model` | (implícito, sin `build.gradle` propio con dependencias externas más allá de Lombok heredado del `main.gradle` raíz) |
| `common` | compartido, sin dependencias externas propias más allá de Lombok/Jackson heredados |

Todas las versiones de librerías Spring se resuelven mediante el BOM `spring-boot-dependencies:4.0.2` (`implementation platform(...)` en `main.gradle`), por lo que no se fijan versiones individuales de `spring-*` en los `build.gradle` de submódulo.

## 5. Particularidades de implementación dignas de mención

- **No hay generación de código en build** (no se detectó `co.com.bancolombia.cleanArchitecture`, MapStruct ni OpenAPI Generator activos en los `build.gradle`), a pesar de que `tasks.withType(JavaCompile)` en `main.gradle` incluye el flag `-Amapstruct.suppressGeneratorTimestamp=true`, sugiriendo que la plantilla común del repositorio anticipa el uso de MapStruct en otros microservicios, aunque `ms_evidence` no lo utiliza (mapeo 100% manual).
- **Doble endpoint de descarga** (`/files/{fileId}/download` público y `/internal/files/{fileId}/download` interno) apunta al mismo caso de uso sin distinguir si el solicitante tiene "derecho" sobre ese `assessmentId` específico — la autorización de pertenencia no está implementada a nivel de archivo individual, solo a nivel de "JWT válido" o "API key válida".
- **UUID aleatorio como `traceId` de negocio en respuestas exitosas**: cada controlador construye `ApiResponseMapper.success(UUID.randomUUID().toString(), ...)`, es decir, el `traceId` de una respuesta 2xx **no** es el mismo `X-Trace-Id` de la petición HTTP (que sí se usa consistentemente en errores vía `GlobalExceptionHandler.getTraceId()`); es una discrepancia real observable entre el flujo de éxito y el flujo de error.
