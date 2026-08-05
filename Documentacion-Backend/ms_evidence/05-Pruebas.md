# ms_evidence — Pruebas

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_evidence` |
| Fecha del documento | 2026-08-19 |
| Alcance | Estrategia de pruebas real del microservicio `ms_evidence`: frameworks, estructura y ausencias evidenciadas |

---

## 1. Frameworks de prueba declarados (verificados en `build.gradle`)

| Framework / librería | Versión | Uso | Módulo(s) que la declaran |
|---|---|---|---|
| JUnit 5 (Jupiter) | gestionada por BOM Spring Boot 4.0.2; `test { useJUnitPlatform() }` en `main.gradle` | Motor de pruebas para todos los módulos | todos (heredado de `main.gradle`) |
| `spring-boot-starter-test` | gestionada por BOM (incluye JUnit 5, Mockito, AssertJ, Spring Test) | Pruebas unitarias y de contexto | todos (`testImplementation` declarada globalmente en `main.gradle`), y explícita además en `api-rest/build.gradle` |
| `spring-security-test` | gestionada por BOM | Simular contexto de seguridad/JWT | `api-rest`, `app-service` |
| Mockito (vía `spring-boot-starter-test`) | gestionada por BOM | *Mocking* de dependencias en pruebas unitarias | módulos con lógica |
| `archunit` | 1.4.1 | Declarada como dependencia de prueba en `app-service/build.gradle`, pensada para reglas de arquitectura | `app-service` |
| `org.reactivecommons.utils:object-mapper` | 0.1.0 | Declarada en `jpa-repository/build.gradle` como `testImplementation` | `jpa-repository` |

## 2. Estructura real de carpetas de test (verificada en el repositorio)

```
infrastructure/entry-points/api-rest/src/test/java/co/com/mspi/api/
├── config/CorsConfigTest.java
├── config/TraceIdFilterTest.java
└── exception/GlobalExceptionHandlerTest.java
```

Se identificaron **3 clases de prueba** en todo el repositorio de `ms_evidence`, todas concentradas en el módulo `api-rest`, y todas sobre componentes transversales de infraestructura HTTP (CORS, trazabilidad, manejo de excepciones), no sobre la lógica de negocio del dominio.

### 2.1 Módulos sin pruebas propias (ausencia explícita)

- **`domain/model` (`:model`)** — sin carpeta `src/test`. Contiene únicamente POJOs (`@Data @Builder`) sin lógica, coherente con la ausencia de pruebas.
- **`domain/usecase` (`:usecase`)** — **sin carpeta `src/test`**, a pesar de concentrar toda la lógica de negocio real del microservicio (11 casos de uso con validaciones, cálculo de cobertura, reglas de MIME/tamaño, *merge* de campos). Esta es la ausencia más significativa detectada: ninguna de las reglas descritas en `02-Analisis.md` §4 (validaciones de subida, cálculo de cobertura, reglas de clonación de levantamiento, etc.) tiene una prueba unitaria que la respalde en el repositorio actual.
- **`infrastructure/driven-adapters/jpa-repository` (`:jpa-repository`)** — declara `testImplementation 'org.reactivecommons.utils:object-mapper:0.1.0'` en su `build.gradle`, pero **no existe carpeta `src/test`** con clases de prueba: la dependencia está declarada sin uso, señal de una prueba planeada (posiblemente para `EvidenceJpaAdapter` o los repositorios Spring Data) que no llegó a implementarse.
- **`applications/app-service` (`:app-service`)** — sin pruebas propias, a pesar de contener lógica no trivial: `LocalFileStorageAdapter` (cálculo de hash, manejo de rutas, protección contra path traversal), `InternalApiKeyFilter` (validación de clave), `InfisicalConfig`/`DBCredentialConfig` (parseo de secretos). Ninguno de estos componentes tiene prueba unitaria evidenciada.

## 3. Tipos de prueba evidenciados (los 3 casos reales)

### 3.1 `CorsConfigTest`

Prueba unitaria pura (sin contexto Spring): instancia `CorsConfig` directamente y llama a `corsFilter(originsConfig)` con distintos valores de entrada (múltiples orígenes separados por coma, cadena vacía, un solo origen), verificando que el `FilterRegistrationBean<CorsFilter>` resultante no sea nulo y tenga la precedencia esperada (`Ordered.HIGHEST_PRECEDENCE`).

### 3.2 `TraceIdFilterTest`

Usa `@ExtendWith(MockitoExtension.class)` con `HttpServletRequest`/`HttpServletResponse`/`FilterChain` mockeados (Mockito puro, sin `MockMvc` ni contexto Spring). Verifica tres ramas: header `X-Trace-Id` presente (se reutiliza), ausente (se genera un UUID) y en blanco (también se genera), además de confirmar que el MDC se limpia tras completar la cadena de filtros (`assertNull(MDC.get(...))` después de `doFilter`).

### 3.3 `GlobalExceptionHandlerTest`

También con `MockitoExtension` pero **instanciando el handler directamente** (`new GlobalExceptionHandler()`), sin `MockMvc` ni contexto Spring. Cubre las 5 ramas de manejo de excepción (`ResourceNotFoundException` → 404, `BusinessRulesOnFieldsException` → 400, `UserAlreadyExistsException` → 409, `IamServiceException` → 502, `DomainException` → 500) y el caso de `MethodArgumentNotValidException` con múltiples errores de campo, verificando el `traceId` propagado desde el MDC. Nótese que **dos de las excepciones probadas** (`UserAlreadyExistsException`, `IamServiceException`) **no se lanzan nunca** en el código de negocio propio de `ms_evidence` (ver `03-Diseno.md` §2) — son residuo de la plantilla `common` compartida con `ms_iam`.

## 4. Ausencias explícitas

- **No se encontraron pruebas de los 11 casos de uso** (`UploadEvidenceFileUseCase`, `InitLiftingUseCase`, `CloneLiftingUseCase`, `UpdateProcessScopeMetricUseCase`, etc.), pese a que concentran toda la lógica de negocio (validación de MIME/tamaño, cálculo de cobertura, reglas de clonación).
- **No se encontraron pruebas del adaptador de almacenamiento de archivos** (`LocalFileStorageAdapter`): ni del cálculo de hash SHA-256, ni de la protección contra *path traversal*, ni de la organización de directorios por fecha.
- **No se encontraron pruebas del adaptador JPA** (`EvidenceJpaAdapter`), pese a contener lógica de transformación entidad↔dominio y transacciones multi-tabla (`initLifting`, `cloneLifting`).
- **No se encontraron pruebas de los controladores REST** (`EvidenceFileApi`, `AssessmentContextApi`, `LiftingDeliveryApi`, `ProcessScopeApi`, ni los 4 controladores internos) — a diferencia de `ms_iam`, que sí prueba sus controladores con `MockMvc` en modo *standalone*.
- **No se encontraron pruebas de `InternalApiKeyFilter`**, componente de seguridad crítico para las rutas `/internal/**`.
- **No se encontraron pruebas de integración** (`@SpringBootTest`) contra un contexto Spring completo, ni pruebas con base de datos real o embebida (no hay evidencia de Testcontainers ni de H2 en el classpath de test, coherente con que `ms_evidence` no tiene perfil H2 de desarrollo).
- **No se encontró una clase de prueba ArchUnit concreta**, pese a que la dependencia `archunit:1.4.1` está declarada en `app-service/build.gradle` — mismo patrón de discrepancia "dependencia declarada, prueba ausente" observado también en `ms_iam`.
- **No se encontró carpeta `src/test/resources`** con configuración específica de test (`application-test.yaml`).

## 5. Cobertura de código (JaCoCo) y mutation testing (Pitest)

Configurados a nivel del `main.gradle` raíz para **todos los subproyectos** (idéntico mecanismo al de `ms_iam`):

- **JaCoCo 0.8.14** — reporte por módulo (`jacocoTestReport`, encadenado tras `test`) y reporte fusionado multi-módulo (`jacocoMergedReport`).
- **Umbral mínimo obligatorio: 80%** de instrucciones cubiertas (`INSTRUCTION`/`COVEREDRATIO` ≥ `0.80`), enlazado a la tarea `check` (`check.dependsOn jacocoTestCoverageVerification`), con las mismas exclusiones estructurales que `ms_iam` (`MainApplication`, `*Mapper*`, `*Dto*`/`*DTO*`, `jpa.entity.*`, `jpa.repository.*`, `*Entity*`, `*Repository`, `model.*`, `config.*`, `api.config.*`, `common.dto.*`, `common.exception.*`).
- **Dado que `usecase`, `jpa-repository` y `app-service` no tienen pruebas propias, y que las exclusiones de JaCoCo NO cubren el paquete `usecase.evidence` ni `storage`**, es previsible que el build de `check` (`jacocoTestCoverageVerification`) **falle o exija un porcentaje de cobertura no alcanzado** en esos módulos si se ejecuta localmente — no verificado en este análisis por no haberse ejecutado el build, pero deducible directamente de la combinación "sin pruebas + módulo no excluido + umbral 80% obligatorio".
- **Pitest (mutation testing)** — mismo mecanismo multi-módulo que `ms_iam` (`targetClasses = ['co.com.mspi.*']`, agregación vía `pitestReportAggregate`), con la misma limitación: sin pruebas en `usecase`/`jpa-repository`, las mutaciones generadas en esos módulos no tendrán *tests* que las maten, por lo que el puntaje de mutación real esperado en esos módulos es bajo o nulo.
- **SonarQube** — plugin `org.sonarqube` 7.2.2.6593 configurado a nivel de todo el proyecto multi-módulo, consumiendo JaCoCo y Pitest fusionados; no se encontró evidencia de que el pipeline de CI (`bitbucket-pipelines.yml`) invoque `sonar` o `check` (ver `06-Implementacion-Despliegue.md`).

## 6. Estrategia de pruebas recomendada

El pipeline de CI (`bitbucket-pipelines.yml`) solo ejecuta `./gradlew clean assemble`, **sin `test` ni `check`**, por lo que la cobertura real del proyecto no se valida automáticamente antes del despliegue. Dada la concentración de lógica de negocio no probada en `domain/usecase`, se recomienda priorizar:

1. Pruebas unitarias de los 11 casos de uso con los gateways mockeados (mismo patrón usado en `ms_iam` para `LoginUseCaseTest`), en especial `UploadEvidenceFileUseCase` (validaciones de MIME/tamaño/relación) y `UpdateProcessScopeMetricUseCase` (cálculo de cobertura y bandera de inconsistencia).
2. Pruebas del adaptador `LocalFileStorageAdapter`, incluyendo casos adversos de *path traversal* (`objectKey` con `../`) y verificación del hash SHA-256 calculado contra un archivo de prueba conocido.
3. Pruebas de `EvidenceJpaAdapter.initLifting`/`.cloneLifting` (idealmente con Testcontainers + PostgreSQL, dado que el proyecto no usa H2), verificando atomicidad transaccional.
4. Pruebas `MockMvc` de los controladores REST (públicos e internos), en particular la validación del header `X-Internal-Api-Key` en `InternalApiKeyFilter`.
5. Agregar `./gradlew check` como etapa explícita en `bitbucket-pipelines.yml` antes del despliegue, para que el pipeline falle si el umbral de cobertura del 80% no se cumple.
