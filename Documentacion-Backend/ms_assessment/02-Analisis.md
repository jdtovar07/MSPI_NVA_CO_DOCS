# ms_assessment — Análisis

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_assessment` |
| Fecha del documento | 2026-08-18 |
| Alcance | Requerimientos funcionales/no funcionales, reglas de negocio y casos de uso implementados en `domain/usecase`, tal como están en el código |

---

## 1. Actores

| Actor | Descripción | Evidencia |
|---|---|---|
| **Evaluador** (usuario autenticado JWT) | Actor humano que crea, edita, califica y publica evaluaciones de su organización a través de `/assessments/**` | `SecurityConfig` (`requestMatchers("/assessments/**").authenticated()`), `CurrentUserResolver` |
| **ms_org** (sistema externo) | Provee los datos de la organización a validar al crear una evaluación | `OrganizationGatewayAdapter`, `OrganizationGateway` |
| **ms_catalog** (sistema externo) | Provee la plantilla activa y todo el contenido evaluable (controles, PHVA, madurez, NIST, presets de áreas, dominios ISO, escala, reglas) | `CatalogGatewayAdapter`, `CatalogGateway` |
| **ms_evidence** (sistema externo) | Gestiona el levantamiento documental asociado a la evaluación (init/clone) y aporta el contexto de auto-percepción del tablero diagnóstico | `EvidenceGatewayAdapter`, `EvidenceGateway` |
| **ms_iam** (sistema externo) | Sumidero de auditoría de eventos de negocio y resolutor de identidad interna del usuario autenticado | `IamAuditGatewayAdapter`, `IamUserGatewayAdapter` |
| **ms_reporting** (sistema externo, S2S) | Consume la API interna (`/internal/assessments/**`) con `X-Internal-Api-Key` para construir reportes/exportables | `InternalAssessmentReportingApi` |

## 2. Requerimientos funcionales (verificados en `domain/usecase`)

| ID | Requerimiento | Caso de uso / clase |
|---|---|---|
| RF-01 | Crear una evaluación en estado `BORRADOR`, validando organización, resolviendo la plantilla activa (o una explícita) y materializando snapshots de controles, PHVA, madurez, NIST y áreas | `CreateAssessmentUseCase` |
| RF-02 | Consultar y actualizar metadatos de una evaluación existente | `GetAssessmentUseCase`, `UpdateAssessmentUseCase` |
| RF-03 | Asignar el tipo de orden territorial (`entityOrderTypeCode`) a la evaluación, con auditoría en `ms_iam` | `AssignEntityOrderTypeUseCase` |
| RF-04 | Publicar una evaluación (`BORRADOR` → `CERRADA`), validando tipo de entidad asignado y control de concurrencia optimista (`rowVersion`), con registro de auditoría | `PublishAssessmentUseCase` |
| RF-05 | Clonar una evaluación **publicada** (`CERRADA`) hacia una nueva evaluación `BORRADOR`, copiando áreas, snapshot de controles/PHVA/madurez/NIST y el levantamiento documental | `CloneAssessmentUseCase` |
| RF-06 | Listar áreas de la evaluación con sus temas/procesos y responsable por defecto | `GetAssessmentAreasUseCase` |
| RF-07 | Reemplazar el listado de temas de un área (`PUT` completo, no incremental) | `ReplaceAssessmentAreaTopicsUseCase` |
| RF-08 | Listar controles de la evaluación (filtrables por `controlType` ADMIN/TECH) y obtener el detalle de un control (incluye contexto de evidencia) | `ListAssessmentControlsUseCase`, `GetControlDetailUseCase` |
| RF-09 | Calificar un control (score, evidencia, brecha, recomendación, estado) aplicando reglas de completitud del catálogo | `PatchControlScoreUseCase` |
| RF-10 | Consultar y modificar el responsable (steward) de un control, ya sea heredado del área (`FROM_AREA`) o explícito (`CUSTOM`) | `GetControlStewardsUseCase`, `PatchControlStewardUseCase` |
| RF-11 | Calcular el **rollup** (agregación jerárquica recursiva) del árbol de controles, con promedio, banda de madurez y contadores de calificación/completitud | `ComputeAssessmentRollupUseCase` |
| RF-12 | Listar ítems PHVA (filtrables por componente P/H/V/A) y calificarlos | `ListPhvaItemsUseCase`, `PatchPhvaItemScoreUseCase` |
| RF-13 | Calcular el avance PHVA esperado vs. real (`overallBreach`) | `ComputePhvaAdvanceUseCase` |
| RF-14 | Listar requisitos de madurez (filtrables por `sourceType`, `level`, `status`) y calificarlos | `ListMaturityRequirementsUseCase`, `PatchMaturityRequirementScoreUseCase` |
| RF-15 | Calcular el resumen de madurez: matriz de cumplimiento por nivel (1–5), nivel alcanzado, categoría por nivel (SUFICIENTE/INTERMEDIO/CRÍTICO) y bloqueos al siguiente nivel | `ComputeMaturitySummaryUseCase` |
| RF-16 | Listar ítems NIST Ciber (filtrables por `functionCode`, `sourceType`) y calificarlos | `ListNistCiberItemsUseCase`, `PatchNistCiberItemScoreUseCase` |
| RF-17 | Calcular el resumen NIST por función (promedio, estado ALCANZA/NO ALCANZA, brecha respecto al objetivo) | `ComputeNistSummaryUseCase` |
| RF-18 | Calcular la efectividad por dominio ISO (14 dominios de portada + promedio global) | `ComputeDomainEffectivenessUseCase` |
| RF-19 | Calcular el tablero diagnóstico agregando efectividad por dominio, avance PHVA, resumen de madurez, resumen NIST y comparación de auto-percepción (`ms_evidence`) | `ComputeDiagnosticDashboardUseCase` |
| RF-20 | Listar brechas priorizadas (score por debajo de un umbral, por defecto 60), con filtros por dominio ISO y rol de responsable, ordenadas por dominio y score ascendente | `ListGapsUseCase` |
| RF-21 | Construir el bundle de exportación agregado (evaluación + diagnóstico + brechas + controles + PHVA + madurez + NIST + áreas) para `ms_reporting` | `BuildReportExportBundleUseCase` |

## 3. Requerimientos no funcionales (verificados en configuración/código)

| ID | Requerimiento | Evidencia |
|---|---|---|
| RNF-01 | Autenticación stateless mediante JWT (OAuth2 Resource Server), sin sesión de servidor | `SecurityConfig` (`SessionCreationPolicy.STATELESS`) |
| RNF-02 | La API interna debe rechazar peticiones sin `X-Internal-Api-Key` válida, incluso devolviendo `503` si la clave no está configurada en el servidor (fail-safe explícito) | `InternalApiKeyFilter` |
| RNF-03 | Cabeceras de seguridad HTTP: `X-Frame-Options: DENY`, HSTS (1 año, incluye subdominios, preload) | `SecurityConfig.securityFilterChain` |
| RNF-04 | Trazabilidad de peticiones: cada request recibe/propaga `X-Trace-Id`, registrado en MDC y en logs de inicio/fin con duración | `TraceIdFilter` |
| RNF-05 | Control de concurrencia optimista en la publicación de evaluaciones vía `rowVersion` | `PublishAssessmentUseCase`, `RowVersionRequest` (DTO de entrada) |
| RNF-06 | Cobertura mínima de instrucciones del 80% exigida por build (`jacocoTestCoverageVerification`, enlazada a `check`) | `main.gradle` |
| RNF-07 | El microservicio no debe ejecutar DDL automáticamente en producción (`spring.sql.init.mode: never`, `hibernate.ddl-auto: none`) | `application.yaml` |
| RNF-08 | Las llamadas de auditoría a `ms_iam` no deben bloquear ni fallar la operación de negocio si el servicio de auditoría no responde (best-effort) | `IamAuditGatewayAdapter` (captura genérica `catch (Exception ex)` con `log.warn`) |
| RNF-09 | CORS restringido a una lista explícita de orígenes configurada por variable de entorno, sin comodín | `CorsConfig` (`CORS_ALLOWED_ORIGINS`) |
| RNF-10 | Todas las respuestas exitosas siguen un envoltorio uniforme `CorrectResponse{meta,data}` con `traceId` y `timestamp`; los errores siguen `ErrorResponse{meta,error[]}` | `ApiResponseMapper`, `GlobalExceptionHandler` |

## 4. Reglas de negocio del dominio (evaluación y madurez)

Extraídas de `domain/usecase` y de los comentarios Javadoc que referencian historias de usuario (HU-*):

### 4.1 Ciclo de vida y edición

- **Regla de estados**: una evaluación nace `BORRADOR` y solo puede llegar a `CERRADA` mediante `PublishAssessmentUseCase`; no existe transición inversa (`CERRADA` → `BORRADOR`) en el código.
- **Bloqueo de edición al publicar**: `PatchControlScoreUseCase` rechaza cualquier calificación si `assessment.status == CERRADA` (`BusinessRulesOnFieldsException`).
- **Requisito para publicar**: `entityOrderTypeCode` debe estar asignado (no vacío) antes de publicar.
- **Concurrencia optimista**: publicar exige que `rowVersion` enviado coincida exactamente con el vigente; en caso contrario, `BusinessRulesOnFieldsException` ("Conflicto de versión").
- **Clonación restringida**: solo se puede clonar una evaluación en estado `CERRADA` (evaluación ya publicada); el clon nace `BORRADOR`, sin `entityOrderTypeCode` ni `phvaExpectedAdvanceSnapshot`, y referencia a la fuente vía `clonedFromAssessmentId`.

### 4.2 Calificación de controles (HU-ADM-01)

- `scoreStatus` solo admite `SCORED` o `NA`; si es `NA`, `scoreValue` debe quedar nulo (regla explícita, con mensaje de error dedicado).
- Si `SCORED` y se envía un `scoreValue`, debe pertenecer a la escala publicada por `ms_catalog` (`listPublishedScaleLevels`), típicamente `{0,20,40,60,80,100}` más el nivel `N/A`.
- Solo los nodos hoja marcados `isScored()=true` en el snapshot admiten calificación (`GetControlDetailUseCase`/`PatchControlScoreUseCase` rechazan nodos de agrupación).
- Al marcar un control `COMPLETADO`, se activan validaciones condicionadas por `ControlRuleInfo` (reglas del catálogo, indexadas por nodo de catálogo origen):
  - `requiresEvidence` → exige `evidenceText` no vacío.
  - `requiresGap` → exige `gapText` no vacío.
  - `requiresRecommendation` → exige `recommendationText` no vacío, **solo si el score está por debajo del umbral** cuando `recommendationRuleType = THRESHOLD` (comparación estricta `<`); si la regla no es de tipo `THRESHOLD`, la recomendación es siempre obligatoria al completar.
- `scoreValue` es obligatorio para poder marcar `COMPLETADO` cuando `scoreStatus = SCORED`.

### 4.3 Rollup jerárquico (HU-ADM-02/03, HU-TEC-02)

Algoritmo documentado en el propio código (`ComputeAssessmentRollupUseCase`), de hojas hacia raíz:

- **Hoja**: si `control_response.score_status = NA` → no aporta valor (excluida del promedio); si `SCORED` con `score_value` no nulo → aporta ese valor.
- **Nodo interno**: promedio simple redondeado *half-up* de los hijos que sí tienen valor calculable; si tiene un único hijo calculable, hereda directamente su valor (sin promediar).
- **No calculable**: si ningún descendiente aporta valor, el promedio es `null` (no se fuerza a 0).
- **Banda de madurez**: se determina buscando, entre las bandas publicadas por `ms_catalog` (`ScaleBandInfo`), aquella donde `min ≤ valor ≤ max`; el mismo criterio se aplica al promedio global (`overallAverage`).
- El resultado incluye contadores agregados: `totalScoredControls` (calificados) y `completedControls` (`control_status = COMPLETADO`).
- El cálculo puede restringirse por `controlType` (`ADMIN`/`TECH`) o ejecutarse sobre el árbol completo.

### 4.4 Ítems PHVA (HU-PHVA-01..04)

`PhvaScoreResolver` resuelve el "valor efectivo" (F_n) de cada ítem PHVA según su `scoringMode`:

- `MANUAL` → toma directamente la respuesta capturada (`NA` → null; `SCORED` → `scoreValue`).
- `INHERITED` → según `inheritRule`:
  - `CONTROL_SCORE` → hereda el `scoreValue` del control asociado (nulo si ese control está `NA`).
  - `CONTROL_ROLLUP` → hereda el promedio calculado del rollup para el nodo de control asociado.
  - `ANEXO_A_OVERALL` → hereda el promedio global (`overallAverage`) del rollup completo.

### 4.5 Requisitos de madurez (HU-MAD-01..05)

`MaturityScoreResolver` extiende la misma lógica de herencia de PHVA añadiendo dos reglas adicionales de composición:

- `INHERIT_PHVA_ITEM_SCORE` → hereda el valor efectivo de un ítem PHVA específico (resuelto recursivamente con `PhvaScoreResolver`).
- `INHERIT_PHVA_COMPOSITE_AVG` → promedia los valores efectivos de una lista de códigos PHVA (`compositePhvaCodes`).
- **Matriz de cumplimiento**: para cada requisito y cada nivel (1–5) se compara el valor efectivo (`F_n`) contra el umbral esperado (`MaturityThresholdSnapshot.expectedValue`) de ese nivel: `CUMPLE` (igual), `MENOR` (por debajo), `MAYOR` (por encima), o `N/A` si el umbral está marcado `is_na` o no hay valor calculable.
- **Nivel alcanzado**: se evalúa secuencialmente de nivel 1 a 5; el primer nivel donde exista al menos un requisito en estado `MENOR` determina el techo alcanzado (etiquetas: "NO ALCANZA NIVEL INICIAL", "INICIAL", "GESTIONADO", "DEFINIDO", "GESTIONADO CUANTITATIVAMENTE", "OPTIMIZADO") — modelo inspirado en CMMI de 5 niveles.
- **Categoría por nivel**: se compara el conteo de requisitos `MENOR` en el nivel contra los umbrales `sufficientMax`/`intermediateMax` configurados por plantilla (`maturity_crit_thresholds` en `catalog.template_version`, ver `maturity_data.sql`): `SUFICIENTE` si está bajo `sufficientMax`, `INTERMEDIO` si está bajo `intermediateMax`, en otro caso `CRÍTICO`.
- **Bloqueo al siguiente nivel**: identifica el primer nivel no cumplido y lista los requisitos en estado `MENOR` de ese nivel como bloqueantes explícitos (`MaturityBlockingRequirement`).

### 4.6 Ítems NIST Ciber (HU-CIB-01..03)

`NistCiberScoreResolver` es más simple: solo soporta `MANUAL` o `INHERITED`+`CONTROL_SCORE` (no soporta rollup ni PHVA como madurez/PHVA). El resumen por función (`ComputeNistSummaryUseCase`) compara el promedio contra un objetivo y calcula estado `ALCANZA`/`NO ALCANZA` con brecha (`target - average`, nunca negativa).

### 4.7 Brechas priorizadas (HU-REP-03)

`ListGapsUseCase`:

- Una fila es "brecha" si `score_status = SCORED`, tiene `score_value` no nulo, y `score_value < umbral` (por defecto **60**).
- Filtros opcionales por `isoDomainCode` y `stewardRoleCode` (comparación *case-insensitive*).
- **Prioridad**: `ALTA` si `score < 40`, `MEDIA` si `40 ≤ score < 60`, `BAJA` en el resto (aunque solo entran a la lista los que ya son `< umbral`).
- **Recomendación**: usa `recommendationText` capturado si existe; si está vacío, cae a `test_guidance` del snapshot del control (comportamiento *fallback*).
- **Orden**: por posición de despliegue del dominio ISO (`displayPosition`, catálogo) y luego por `score` ascendente.
- **Área responsable**: se resuelve indexando los temas de área por `defaultStewardRoleCode`, tomando el primer nombre de área encontrado por rol (`putIfAbsent`).

### 4.8 Efectividad por dominio (HU-DIAG-01)

`ComputeDomainEffectivenessUseCase` reutiliza el rollup general, localizando los nodos de tipo `DOMAIN` en el árbol (14 dominios "de portada" ISO 27001) e indexándolos por código ISO. El objetivo fijo es **100** para todos los dominios; se marca `calculable=false` cuando no hay score (dominio sin controles calificados).

### 4.9 Tablero diagnóstico (HU-DIAG-02..04)

`ComputeDiagnosticDashboardUseCase` agrega, en una sola respuesta, los cuatro cálculos anteriores (efectividad por dominio, avance PHVA, resumen de madurez, resumen NIST) más una comparación de auto-percepción obtenida de `ms_evidence` (`GET /internal/assessments/{id}/context`), fusionando ambas fuentes en `SelfPerceptionComparison`.

## 5. Casos de uso (resumen operativo)

| Caso de uso | Entrada principal | Salida | Efectos secundarios |
|---|---|---|---|
| `CreateAssessmentUseCase` | `CreateAssessmentCommand`, `createdBy` | `Assessment` | Inserta assessment + member líder + historial de estado + snapshots (controles, PHVA, madurez, NIST, áreas); llama a `ms_evidence.initLifting` |
| `PublishAssessmentUseCase` | `assessmentId`, `rowVersion`, `publishedBy` | `Assessment` actualizado | Inserta historial de estado; audita `ASSESSMENT_PUBLISHED` en `ms_iam` (best-effort) |
| `CloneAssessmentUseCase` | `sourceAssessmentId`, `createdBy`, nombre evaluador | `Assessment` nuevo | Clona áreas/controles/PHVA/madurez/NIST; llama a `ms_evidence.cloneLifting` |
| `PatchControlScoreUseCase` | `assessmentId`, `assessmentControlNodeId`, `PatchControlScoreCommand` | *(void)* | Valida contra escala y reglas del catálogo; persiste respuesta de control |
| `ComputeAssessmentRollupUseCase` | `assessmentId`, `controlType` opcional | `RollupResult` (árbol) | Ninguno (lectura pura) |
| `ComputeMaturitySummaryUseCase` | `assessmentId` | `MaturitySummaryResult` | Ninguno (lectura pura, invoca rollup internamente) |
| `ListGapsUseCase` | `assessmentId`, `threshold`, filtros | `GapListResult` | Ninguno (lectura pura) |
| `BuildReportExportBundleUseCase` | `assessmentId` | `ReportExportBundle` | Ninguno (orquesta 7 casos de uso de lectura) |

## 6. Ausencias explícitas

- No se encontró código de **workflow de aprobación multiusuario** (roles diferenciados como "Revisor" no aparecen en `SecurityConfig`; toda ruta bajo `/assessments/**` solo exige `authenticated()`, sin `@PreAuthorize` por rol específico en los controladores revisados).
- No hay soft-delete ni endpoint de eliminación de evaluaciones en el código (`AssessmentPersistenceGateway` no declara ningún método `delete`).
- No se encontró notificación (correo/webhook) al publicar o calificar; el único efecto colateral observado es la auditoría best-effort hacia `ms_iam`.
