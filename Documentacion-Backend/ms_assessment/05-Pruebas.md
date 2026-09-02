# ms_assessment — Pruebas

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_assessment` |
| Fecha del documento | 2026-08-19 |
| Alcance | Estrategia de pruebas real del microservicio `ms_assessment`: frameworks, estructura, tipos de prueba evidenciados y configuración de cobertura |

---

## 1. Frameworks de prueba (verificados en `build.gradle`)

| Framework / librería | Versión | Uso | Módulo(s) |
|---|---|---|---|
| JUnit 5 (Jupiter) | gestionada por BOM Spring Boot 4.0.2; `test { useJUnitPlatform() }` en `main.gradle` | Motor de pruebas para todos los módulos | todos |
| `spring-boot-starter-test` | gestionada por BOM (incluye JUnit 5, Mockito, AssertJ, Spring Test) | Pruebas unitarias | todos (`testImplementation` en `main.gradle`) |
| `spring-security-test` | gestionada por BOM | Simular contexto de seguridad en pruebas de `api-rest`/`app-service` | `api-rest`, `app-service` (declarada) |
| Mockito (vía `spring-boot-starter-test`) | gestionada por BOM | *Mocking* de gateways/puertos | `usecase`, `api-rest` |
| `archunit` | 1.4.1 | Declarada en `app-service`, **sin clase de prueba asociada** | `app-service` |
| `object-mapper` (reactivecommons) | 0.1.0 | Declarada en `jpa-repository`, **sin uso confirmado en clases de prueba existentes** | `jpa-repository` |

No hay MockWebServer/OkHttp ni ninguna otra librería de simulación HTTP declarada (a diferencia de `ms_iam`, que la usa para probar `KeycloakAuthAdapter`): **no existe ninguna clase de prueba para los 5 adaptadores de `rest-consumer`** (`CatalogGatewayAdapter`, `OrganizationGatewayAdapter`, `EvidenceGatewayAdapter`, `IamAuditGatewayAdapter`, `IamUserGatewayAdapter`).

## 2. Estructura de carpetas de test (real, verificada en el repositorio)

```
domain/usecase/src/test/java/co/com/mspi/usecase/assessment/
├── ComputeAssessmentRollupUseCaseTest.java
├── ComputeDomainEffectivenessUseCaseTest.java
├── ComputePhvaAdvanceUseCaseTest.java
├── ListGapsUseCaseTest.java
├── MaturityScoreResolverTest.java
├── NistCiberScoreResolverTest.java
└── PatchControlScoreUseCaseTest.java

infrastructure/entry-points/api-rest/src/test/java/co/com/mspi/api/
├── config/CorsConfigTest.java
├── config/TraceIdFilterTest.java
└── exception/GlobalExceptionHandlerTest.java
```

En total se identificaron **10 clases de prueba**, todas concentradas en 2 de los 7 módulos del proyecto (`:usecase` y `:api-rest`). Los módulos `:model`, `:common`, `:jpa-repository`, `:rest-consumer` y `:app-service` **no tienen ninguna prueba propia** en el repositorio. Esta es una cobertura estructural notablemente menor que la de `ms_iam` (21 clases en 7 de 9 módulos): `ms_assessment` prueba en profundidad el **núcleo de cálculo de dominio** (rollup, madurez, NIST, brechas, calificación de controles) pero deja sin prueba automatizada toda la capa de persistencia JPA, todos los adaptadores REST salientes, y 8 de los 9 controladores REST (`AssessmentApi`, `AssessmentAreasApi`, `AssessmentControlApi`, `AssessmentPhvaApi`, `AssessmentMaturityApi`, `AssessmentNistApi`, `AssessmentDiagnosticApi`, `AssessmentGapsApi`, `ControlStewardApi`, `InternalAssessmentReportingApi` — ninguno tiene test propio, solo se prueban la configuración transversal `CorsConfig`/`TraceIdFilter` y el `GlobalExceptionHandler`).

## 3. Tipos de prueba evidenciados

### 3.1 Pruebas unitarias de casos de uso y resolvers (`domain/usecase`)

- **`ComputeAssessmentRollupUseCaseTest`**: construye árboles de `ControlNodeSnapshot` sintéticos con mocks de `AssessmentPersistenceGateway`/`CatalogGateway` (`Mockito.mock`, sin `@ExtendWith(MockitoExtension.class)` estricto — usa `mock()` estático), y verifica el algoritmo de agregación (promedio *half-up*, herencia de hijo único, `ResourceNotFoundException` si la evaluación no existe).
- **`ComputeDomainEffectivenessUseCaseTest`**, **`ComputePhvaAdvanceUseCaseTest`**: prueban los cálculos derivados del rollup con `@Mock`/`@InjectMocks` de Mockito (`MockitoExtension`).
- **`ListGapsUseCaseTest`**: verifica filtrado por umbral/dominio/rol y el criterio de prioridad (`ALTA`/`MEDIA`/`BAJA`).
- **`MaturityScoreResolverTest`**: prueba unitaria **pura sin mocks** (la clase es `final` con métodos estáticos) sobre `compareStatus` (CUMPLE/MENOR/MAYOR/N-A) y `computeNivelAlcanzado` (mapa de niveles cumplidos → etiqueta CMMI), replicando ejemplos documentados en las historias de usuario (comentario `compareStatus_r1ExampleFromHu`).
- **`NistCiberScoreResolverTest`**: igualmente sin mocks; prueba `averageScores` (redondeo half-up, lista vacía → `null`), `computeStatus` (ALCANZA/NO ALCANZA) y `computeBreach`.
- **`PatchControlScoreUseCaseTest`**: `@ExtendWith(MockitoExtension.class)` con `@MockitoSettings(strictness = Strictness.LENIENT)` (implícito por el `import` de `Strictness`), verifica rechazo de calificación fuera de escala, bloqueo cuando `assessment.status == CERRADA`, y las reglas condicionales de completitud (`requiresEvidence`/`requiresGap`/`requiresRecommendation` con `THRESHOLD`).

### 3.2 Pruebas de configuración HTTP transversal (`api-rest`)

- **`CorsConfigTest`**: verifica que `CorsConfig.corsFilter(origins)` construye un `FilterRegistrationBean<CorsFilter>` con orden `Ordered.HIGHEST_PRECEDENCE`, cubriendo el caso de orígenes vacíos.
- **`TraceIdFilterTest`**: mockea `HttpServletRequest`/`HttpServletResponse`/`FilterChain` y verifica la propagación de `traceId` vía MDC.
- **`GlobalExceptionHandlerTest`**: recorre los 6 manejadores de excepción (`ResourceNotFoundException`, `BusinessRulesOnFieldsException`, `UserAlreadyExistsException`, `IamServiceException`, `MethodArgumentNotValidException`, `DomainException`) verificando el código HTTP y el `code` de negocio devueltos.

### 3.3 Ausencias explícitas

- **No hay pruebas de los 9 controladores REST del dominio de negocio** (`AssessmentApi`, `AssessmentControlApi`, etc.) ni con `MockMvc` ni con `@SpringBootTest`: a diferencia de `ms_iam` (que sí prueba `AuthApi`/`UsersApi`/`RolesApi` con MockMvc standalone), `ms_assessment` no tiene ninguna prueba de entry point HTTP más allá de la configuración transversal y el manejador de errores.
- **No hay pruebas de los adaptadores de persistencia** (`AssessmentJpaAdapter`, el único adaptador de `:jpa-repository`, con 39 métodos) ni de configuración JPA (`JpaConfig`), pese a que `ms_iam` sí prueba su adaptador de auditoría (`AuthAuditAdapterTest`) y su configuración de conexión (`JpaConfigTest`).
- **No hay pruebas de ningún adaptador `rest-consumer`** (`CatalogGatewayAdapter`, `OrganizationGatewayAdapter`, `EvidenceGatewayAdapter`, `IamAuditGatewayAdapter`, `IamUserGatewayAdapter`), ni con MockWebServer ni con ningún otro mecanismo — es la brecha de cobertura más significativa dado que este microservicio depende fuertemente de 4 integraciones HTTP salientes para materializar snapshots.
- **No hay pruebas para 21 de los 28 casos de uso**: solo 7 casos de uso tienen clase de test dedicada (`ComputeAssessmentRollupUseCase`, `ComputeDomainEffectivenessUseCase`, `ComputePhvaAdvanceUseCase`, `ListGapsUseCase`, `PatchControlScoreUseCase`, más los 2 resolvers). Casos de uso centrales como `CreateAssessmentUseCase`, `PublishAssessmentUseCase`, `CloneAssessmentUseCase`, `ComputeMaturitySummaryUseCase`, `ComputeNistSummaryUseCase`, `ComputeDiagnosticDashboardUseCase` y `BuildReportExportBundleUseCase` no tienen prueba unitaria propia en el repositorio.
- **No se encontraron pruebas de integración con `@SpringBootTest`** ni pruebas end-to-end contra PostgreSQL/Testcontainers, igual que en `ms_iam`.
- **No hay clase de prueba ArchUnit** pese a la dependencia declarada `archunit:1.4.1` en `app-service` — misma discrepancia observada en `ms_iam`.
- **No se encontró `src/test/resources`** con configuración de perfil de prueba dedicado.

## 4. Cobertura de código (JaCoCo) y mutation testing (Pitest)

Configuración **idéntica en estructura** a la de `ms_iam` (misma sección `subprojects{}` en `main.gradle`), aplicada a los 7 subproyectos de este repositorio:

- **JaCoCo 0.8.14** — reporte por módulo (`jacocoTestReport`, encadenado tras `test`) y reporte fusionado multi-módulo (`jacocoMergedReport`) para SonarQube.
- **Umbral mínimo obligatorio: 80%** de instrucciones cubiertas (`INSTRUCTION`/`COVEREDRATIO ≥ 0.80`), enlazado a `check` (`check.dependsOn jacocoTestCoverageVerification`), con una lista de exclusión **más amplia** que la de `ms_iam`: además de `MainApplication`, `*Mapper*`, `*Dto*`/`*DTO*`, `*Entity*`, `model.*` y `config.*`, este proyecto excluye explícitamente también `*Request`, `*Response`, `*.dto.*`, `jpa.repository.*` y `*Repository` — reconociendo que gran parte del volumen de clases de `ms_assessment` son DTOs de request/response y repositorios Spring Data sin lógica propia.
  - Dado que **ningún adaptador de `rest-consumer` ni `AssessmentJpaAdapter` tiene prueba propia**, y que estas clases **no están en la lista de exclusión** de cobertura, alcanzar el 80% global depende casi por completo de que el volumen de líneas de `domain/usecase` (bien cubierto) compense el de las clases de infraestructura sin cobertura — un riesgo real de que el build pase el umbral agregado sin que la infraestructura esté realmente probada, o que falle si esos módulos crecen.
- **Pitest** — mismo plugin/configuración multi-módulo que `ms_iam` (`targetClasses = ['co.com.mspi.*']`, 8 hilos, `withHistory = true`, agregación custom `pitestReportAggregate`).
- **SonarQube** — plugin `7.2.2.6593` a nivel de todo el proyecto multi-módulo; igual que en `ms_iam`, el pipeline de CI (`bitbucket-pipelines.yml`) **no invoca `check` ni Sonar** (ver `06-Implementacion-Despliegue.md`), por lo que esta infraestructura de calidad existe en Gradle pero no se ejecuta como *gate* automático.

## 5. Estrategia de pruebas recomendada

Dado que el pipeline actual solo ejecuta `./gradlew clean assemble` (sin `test` ni `check`) antes de desplegar a Railway, y que la cobertura real de pruebas está concentrada casi exclusivamente en el módulo de cálculo de dominio:

1. **Incorporar `./gradlew check` al pipeline** (idéntica recomendación que en `ms_iam`), de forma que el umbral del 80% y las 10 clases de prueba existentes actúen como *gate* real antes de desplegar.
2. **Cerrar la brecha de cobertura de `AssessmentJpaAdapter`**: al ser la única implementación de un puerto de 39 métodos que incluye lógica no trivial (materialización de snapshots, clonación de árboles completos), su ausencia de prueba es el riesgo más alto de regresión silenciosa del proyecto.
3. **Añadir pruebas de los 5 adaptadores `rest-consumer`** con MockWebServer (patrón ya usado en `ms_iam` para `KeycloakAuthAdapterTest`), especialmente `CatalogGatewayAdapter` por ser el más extenso y crítico para la materialización de snapshots.
4. **Añadir pruebas de los 21 casos de uso sin cobertura**, priorizando `CreateAssessmentUseCase`, `PublishAssessmentUseCase` y `CloneAssessmentUseCase` por concentrar las reglas de negocio de ciclo de vida (estado, concurrencia optimista, clonación) descritas en `02-Analisis.md`.
5. **Añadir pruebas MockMvc de al menos los controladores con lógica de mapeo no trivial** (`AssessmentControlApi`, `AssessmentMaturityApi`) siguiendo el patrón *standalone* usado en `ms_iam` (`UsersApiTest`).
6. **Completar o remover la dependencia ArchUnit** declarada sin uso, formalizando la regla de dependencia entre capas descrita en `03-Diseno.md` §1.
