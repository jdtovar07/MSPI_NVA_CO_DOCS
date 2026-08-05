# ms_evidence — Análisis

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_evidence` |
| Fecha del documento | 2026-08-19 |
| Alcance | Requerimientos funcionales/no funcionales, reglas de negocio y casos de uso reales del microservicio `ms_evidence` |

---

## 1. Actores

| Actor | Tipo | Autenticación | Ejemplos de operación |
|---|---|---|---|
| Usuario final autenticado (frontend) | Humano | JWT Bearer (Keycloak, realm `iam`) | Consultar/editar contexto, subir/descargar/listar/eliminar archivos, actualizar entregas de levantamiento |
| `ms_assessment` (microservicio) | Sistema | `X-Internal-Api-Key` | Inicializar levantamiento, clonar levantamiento entre evaluaciones, listar evidencias de un control, consultar contexto |
| `ms_reporting` (microservicio) | Sistema | `X-Internal-Api-Key` | Subir salida de reporte generada (PDF/XLSX), descargar archivo internamente |

No existe un rol de negocio diferenciado (p. ej. `AdminSistema`, `Evaluador`) dentro del propio `ms_evidence`: la autorización a nivel de rol se delega en los microservicios consumidores (`ms_assessment`, frontend) — `ms_evidence` únicamente exige "JWT válido" para las rutas públicas (`.authenticated()` en `SecurityConfig`, sin `hasRole`/`hasAuthority` específico verificado en el código de los controladores).

## 2. Requerimientos funcionales

| ID | Requerimiento | Evidencia en código |
|---|---|---|
| RF-01 | Consultar y actualizar (parcial) el contexto de evaluación de un `assessmentId` (misión, análisis de contexto, mapa de procesos, organigrama, auto-percepción) | `GetAssessmentContextUseCase`, `UpdateAssessmentContextUseCase`, `AssessmentContextApi` |
| RF-02 | Consultar y actualizar la métrica de alcance de procesos, con cálculo automático de cobertura y bandera de inconsistencia | `GetProcessScopeMetricUseCase`, `UpdateProcessScopeMetricUseCase` |
| RF-03 | Inicializar el levantamiento documental de una evaluación a partir de una lista de ítems de catálogo, creando además el contexto y la métrica de alcance en blanco | `InitLiftingUseCase.execute`, `EvidenceJpaAdapter.initLifting` |
| RF-04 | Clonar el levantamiento (contexto + métrica + entregas) desde una evaluación origen hacia una evaluación destino | `CloneLiftingUseCase`, `EvidenceJpaAdapter.cloneLifting` |
| RF-05 | Listar las entregas de levantamiento de una evaluación y actualizar el estado individual de una entrega (`DELIVERED`/`NOT_DELIVERED`/`PARTIAL`), nombre entregado y notas | `GetLiftingDeliveriesUseCase`, `UpdateLiftingDeliveryUseCase`, `LiftingDeliveryApi` |
| RF-06 | Subir un archivo de evidencia (multipart), asociado a `CONTEXT`, `LIFTING_DOC` o `REPORT_OUTPUT`, con validación de tipo MIME, tamaño y campos requeridos según la relación | `UploadEvidenceFileUseCase`, `EvidenceFileApi.upload` |
| RF-07 | Listar archivos de evidencia de una evaluación, filtrables por tipo de relación y por relación específica | `ListEvidenceFilesUseCase`, `EvidenceFileApi.list` |
| RF-08 | Descargar el binario de un archivo de evidencia (Content-Type, Content-Length y Content-Disposition reales del archivo) | `DownloadEvidenceFileUseCase`, `EvidenceFileApi.download` |
| RF-09 | Eliminar (borrado lógico) un archivo de evidencia, intentando además su borrado físico en el filesystem | `DeleteEvidenceFileUseCase`, `EvidenceFileApi.delete` |
| RF-10 | Exponer un canal S2S para que `ms_assessment` inicialice/clone levantamientos y liste evidencias sin JWT de usuario final | `InternalLiftingApi` (`/internal/assessments/**`) |
| RF-11 | Exponer un canal S2S para que `ms_reporting` suba salidas de reporte (PDF/XLSX) y las descargue internamente | `InternalReportOutputApi`, `InternalFileDownloadApi` |
| RF-12 | Exponer el contexto de una evaluación por canal interno (sin JWT), para consumo de `ms_assessment` | `InternalAssessmentContextApi` |

## 3. Requerimientos no funcionales

| ID | Requerimiento | Evidencia |
|---|---|---|
| RNF-01 | Autenticación stateless basada en JWT (sin sesión de servidor) para rutas públicas | `SecurityConfig`: `SessionCreationPolicy.STATELESS` |
| RNF-02 | Autenticación S2S independiente del JWT de usuario, mediante clave compartida en header | `InternalApiKeyFilter` |
| RNF-03 | Tamaño máximo de payload multipart acotado (20 MB por archivo, 22 MB por request; 50 MB para salidas de reporte) para evitar saturación de disco/memoria | `application.yaml` (`spring.servlet.multipart`), `UploadEvidenceFileUseCase.MAX_FILE_SIZE_BYTES` / `MAX_REPORT_SIZE_BYTES` |
| RNF-04 | Integridad de archivo verificable mediante hash SHA-256 calculado en la propia escritura a disco (`DigestOutputStream`), sin relectura adicional del archivo | `LocalFileStorageAdapter.store` |
| RNF-05 | Protección contra *path traversal* al leer o borrar archivos por `objectKey` (normalización + verificación de prefijo contra la raíz configurada) | `LocalFileStorageAdapter.open` / `.delete` |
| RNF-06 | Trazabilidad de peticiones mediante `X-Trace-Id` propagado o generado y expuesto en errores | `TraceIdFilter`, `GlobalExceptionHandler.getTraceId` |
| RNF-07 | Observabilidad mínima vía Spring Boot Actuator (`/actuator/health`, `/actuator/info`), sin autenticación | `SecurityConfig`: rutas `permitAll()` |
| RNF-08 | Cabeceras de seguridad HTTP: `X-Frame-Options: DENY` y HSTS (1 año, incluye subdominios, preload) | `SecurityConfig.securityFilterChain` (`headers { frameOptions... httpStrictTransportSecurity... }`) |
| RNF-09 | El servicio no ejecuta DDL automáticamente; el esquema se aplica de forma externa y versionada | `application.yaml`: `spring.sql.init.mode: never`, `hibernate.ddl-auto: none` |
| RNF-10 | La aplicación no arranca sin credenciales de base de datos válidas (falla explícita, sin fallback silencioso) | `DBCredentialConfig.dbSecret`: `IllegalStateException` si `DB_CREDENTIAL` es nulo/vacío |
| RNF-11 | Cobertura mínima de código del 80% de instrucciones exigida por el build (`jacocoTestCoverageVerification`), con exclusiones explícitas de DTOs/entidades/config | `main.gradle` |

## 4. Reglas de negocio (extraídas de `domain/usecase`)

### 4.1 Subida de evidencia (`UploadEvidenceFileUseCase`)

1. `assessmentId` es obligatorio.
2. `relationType` debe ser uno de `CONTEXT`, `LIFTING_DOC`, `REPORT_OUTPUT`.
3. Si `relationType = CONTEXT`, `contextField` es obligatorio y debe ser `MISSION` o `CONTEXT`; el `relationId` real que se persiste se fuerza al propio `assessmentId` (no se toma del comando del cliente).
4. Si `relationType = LIFTING_DOC` o `REPORT_OUTPUT`, `relationId` es obligatorio (identifica el ítem de levantamiento o el `jobId` del reporte).
5. `filename` no puede ser nulo ni estar en blanco.
6. `contentType` debe estar en el conjunto permitido: `application/pdf`, `application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document` (DOCX), `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` (XLSX), `image/png`, `image/jpeg`. **No se permite ZIP ni ningún otro tipo**, tal como documenta el `README.md`.
7. El tamaño debe ser mayor que 0 y no exceder el límite: 20 MB para `CONTEXT`/`LIFTING_DOC`, 50 MB para `REPORT_OUTPUT`.
8. Solo si todas las validaciones anteriores pasan se invoca `FileStorageGateway.store` (persistencia física) y luego `EvidencePersistenceGateway.saveFile` (metadatos) — el archivo físico se escribe *antes* de confirmar el metadato, por lo que un fallo posterior al guardar el metadato podría dejar un archivo huérfano en disco (no se observó lógica de compensación/rollback transaccional entre ambos pasos).

### 4.2 Descarga y borrado de evidencia

- La descarga (`DownloadEvidenceFileUseCase`) exige que el archivo exista y no esté borrado lógicamente; de lo contrario lanza `ResourceNotFoundException` (mapeada a HTTP 404).
- El borrado (`DeleteEvidenceFileUseCase`) primero intenta eliminar el archivo físico y luego marca `deleted_at` en base de datos; si el borrado físico falla (p. ej. archivo ya inexistente), se registra una advertencia (`log.warn`) pero **no se interrumpe** el borrado lógico.

### 4.3 Inicialización y clonación de levantamiento

- `InitLiftingUseCase`: exige al menos un ítem de catálogo (`documentItemCatalogIds` no vacío) y rechaza la operación si ya existe levantamiento para la evaluación (`liftingExistsForAssessment`). El adaptador JPA crea, en una única transacción, el contexto vacío, la métrica de alcance en cero y una fila `NOT_DELIVERED` por cada ítem de catálogo.
- `CloneLiftingUseCase`: rechaza clonar una evaluación sobre sí misma (origen = destino), exige que el levantamiento origen exista y que el destino **no** tenga levantamiento previo. La clonación copia contexto, métrica de alcance y todas las entregas (conservando estado, nombre entregado, notas y datos de validación), generando nuevos IDs de entrega.

### 4.4 Actualización de contexto y métricas

- `UpdateAssessmentContextUseCase` aplica un *merge* campo a campo (patrón PATCH): cada campo no nulo del *patch* sobrescribe el valor actual; los campos nulos conservan el valor existente. Incrementa `version` en cada actualización (control de versión optimista a nivel de aplicación, no de `@Version` JPA).
- `UpdateProcessScopeMetricUseCase` recalcula `coverage = inScopeProcesses / totalProcesses` (4 decimales, redondeo `HALF_UP`) solo si `totalProcesses > 0`; marca `inScopeExceedsTotal = true` si `inScopeProcesses > totalProcesses` (inconsistencia de captura, se permite guardar pero se señaliza).
- `UpdateLiftingDeliveryUseCase` valida que el nuevo `deliveryStatus` (si se envía) pertenezca a `{DELIVERED, NOT_DELIVERED, PARTIAL}`; de lo contrario lanza `BusinessRulesOnFieldsException` (HTTP 400).

### 4.5 Listado de evidencias

`ListEvidenceFilesUseCase` exige `assessmentId` no nulo; `relationType`/`relationId` son filtros opcionales que se combinan progresivamente en `EvidenceJpaAdapter.findFilesByRelation` (tres variantes de consulta según cuáles filtros llegan), siempre excluyendo archivos con `deleted_at` no nulo.

## 5. Casos de uso (resumen operativo)

| Caso de uso | Actor principal | Precondición | Resultado |
|---|---|---|---|
| Consultar contexto de evaluación | Frontend / `ms_assessment` (interno) | Evaluación existe | 200 con `AssessmentContext` o 404 |
| Actualizar contexto de evaluación | Frontend | Contexto existe | 200 con contexto fusionado, `version+1` |
| Consultar métrica de alcance | Frontend | Métrica existe | 200 con `ProcessScopeMetric` |
| Actualizar métrica de alcance | Frontend | Métrica existe | 200 con cobertura recalculada |
| Inicializar levantamiento (interno) | `ms_assessment` | Levantamiento no existe para la evaluación; catálogo no vacío | 201, filas creadas |
| Clonar levantamiento (interno) | `ms_assessment` | Origen distinto de destino, origen con levantamiento, destino sin levantamiento | 201, datos copiados |
| Listar entregas de levantamiento | Frontend | Evaluación con levantamiento inicializado | 200 con lista de entregas |
| Actualizar entrega individual | Frontend | Entrega existe | 200 con entrega fusionada |
| Subir archivo de evidencia | Frontend / `ms_reporting` (interno, `REPORT_OUTPUT`) | Validaciones de negocio §4.1 | 201 con metadato del archivo |
| Listar archivos de evidencia | Frontend / `ms_assessment` (interno) | `assessmentId` presente | 200 con lista de metadatos |
| Descargar archivo | Frontend / `ms_reporting` (interno) | Archivo existe y no borrado | 200 binario (Content-Disposition attachment) |
| Eliminar archivo | Frontend | Archivo existe | 204 sin cuerpo |

## 6. Ausencias explícitas

- No hay control de autorización por rol dentro de `ms_evidence` (todas las rutas públicas solo exigen `.authenticated()`); el control de "quién puede editar qué evaluación" se asume delegado a otro nivel (frontend/`ms_assessment`) — no verificado en este código.
- No se encontró lógica de compensación/transacción distribuida entre el almacenamiento físico del archivo (`FileStorageGateway.store`) y el guardado de metadatos (`EvidencePersistenceGateway.saveFile`) en `UploadEvidenceFileUseCase`: si falla el segundo paso, el archivo físico queda huérfano.
- No se encontró un mecanismo de cuota de almacenamiento por evaluación u organización (solo límite de tamaño por archivo individual).
- No hay eventos ni mensajería asociados a evidencias (el propio `README.md` declara "Mensajería / eventos: No aplica").
