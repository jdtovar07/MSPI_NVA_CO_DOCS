# ms_reporting — Pruebas

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_reporting` |
| Fecha del documento | 2026-08-19 |
| Alcance | Frameworks de prueba, cobertura real y estado de la suite de pruebas del microservicio `ms_reporting` |

---

## 1. Frameworks configurados (a nivel de build)

Declarados en `main.gradle` (aplicados a **todos** los subproyectos) y en `applications/app-service/build.gradle`:

| Herramienta | Configuración | Alcance |
|---|---|---|
| JUnit 5 (Jupiter) | `test { useJUnitPlatform() }`, `testRuntimeOnly 'org.junit.platform:junit-platform-launcher'` | Todos los módulos |
| `spring-boot-starter-test` | `testImplementation` en todos los subproyectos (incluye JUnit 5, AssertJ, Mockito, JSONassert, etc.) | Todos los módulos |
| Mockito (vía `MockitoExtension`) | Usado explícitamente en el único test de caso de uso | `domain/usecase` |
| AssertJ | Usado explícitamente (`assertThat`, `assertThatThrownBy`) en ambos tests existentes | `domain/usecase` |
| JaCoCo | 0.8.14, con `jacocoTestCoverageVerification` — regla de **80% mínimo de instrucciones cubiertas** (`BUNDLE`/`INSTRUCTION`/`COVEREDRATIO ≥ 0.80`) | Todos los módulos; `check.dependsOn jacocoTestCoverageVerification` |
| Pitest (mutation testing) | Plugin `info.solidsoft.pitest` 1.19.0-rc.3 (build tool) / motor 1.22.0, `targetClasses = ['co.com.mspi.*']`, agregación vía `pitestReportAggregate` | Configurado; sin evidencia de ejecución rutinaria (no invocado en `deployment/Dockerfile` ni en un pipeline de CI, que no existe para este microservicio — ver §4) |
| SonarQube | Plugin `org.sonarqube` 7.2.2.6593, con `sonar.coverage.jacoco.xmlReportPaths` y `sonar.pitest.reportPaths` apuntando a los reportes agregados | Configurado a nivel de `build.gradle` raíz; sin evidencia de conexión a un servidor SonarQube activo en este repositorio |

## 2. Inventario real de pruebas

Se localizaron **exactamente 2 clases de prueba** en todo el repositorio, ambas en el módulo `domain/usecase` (`domain/usecase/src/test/java/co/com/mspi/usecase/reporting/`):

| Clase | Método(s) de prueba | Qué valida |
|---|---|---|
| `CreateReportJobUseCaseTest` | `createsPendingJob` | Con `ReportingPersistenceGateway` mockeado, al ejecutar un comando válido (`FULL_DIAGNOSTIC_PDF`, `pageFormat=A4`), el job devuelto tiene `status == PENDING` |
| `CreateReportJobUseCaseTest` | `rejectsInvalidPageFormat` | Con `pageFormat="LEGAL"` (no `A4`/`LETTER`) y `reportType=FULL_DIAGNOSTIC_PDF`, se lanza `BusinessRulesOnFieldsException` |
| `MspiPortadaTemplateFillerTest` (paquete `engine`) | `fillsPortada2022CellsFromDiagnosticDashboard` | Bundle en memoria: verifica hoja única `PORTADA`; header E10–E13; dominio A.5 G/H/I fila 19; PHVA F30/F34/F37 desde `clauses[]`; NIST GV fila 53 cols C/D |

**Cobertura funcional real de la suite**: valida la regla de negocio de creación de jobs (RN-01/RN-02 parcial) y la lógica más intrincada del microservicio (el mapeo celda-por-celda de la plantilla PORTADA). **No existen pruebas** para:

- `ProcessReportJobUseCase` (orquestación completa del job: transición de estados, manejo de excepciones, llamada a los 3 generadores restantes).
- `DownloadReportJobUseCase` (ninguno de sus 3 caminos: caché local, respaldo remoto, `ResourceNotFoundException`).
- `GetReportJobUseCase`.
- `CreateComparativeReportJobUseCase` (ninguna de las reglas RN-05/RN-06/RN-07/RN-08: mínimo 2 evaluaciones, misma organización, rol PRIMARY/COMPARISON).
- `ReportOutputEvidenceArchiver` (comportamiento *best effort* ante fallo de `ms_evidence`).
- `ReportDocumentService` (los 3 métodos que no son el relleno de plantilla: `buildGapListPdf`, `buildGapListXlsx`, `buildComparativePdf`).
- `LibreOfficePdfConverter` (candidatos de ejecutable, timeout, `Redirect.DISCARD`, perfil `UserInstallation` temporal, limpieza de directorios).
- `ReportArtifactDescriptor` (nombres/MIME por tipo de reporte).
- Todo el módulo `infrastructure/entry-points/api-rest` (controladores `ReportJobApi`/`ComparativeReportJobApi`, `GlobalExceptionHandler`, `ReportJobApiMapper`, `JwtSupport`) — sin pruebas de *slice* (`@WebMvcTest`) ni de integración.
- Todo el módulo `infrastructure/driven-adapters/jpa-repository` (`ReportingJpaAdapter`, mapeo entidad↔dominio) — sin `@DataJpaTest` ni pruebas con `Testcontainers`/H2.
- Todo el módulo `infrastructure/driven-adapters/rest-consumer` (los 3 adaptadores HTTP) — sin `MockWebServer`/`WireMock`.
- El módulo `applications/app-service` completo, incluyendo `FileSystemReportOutputStorage` (persistencia en disco) y toda la configuración Spring (`SecurityConfig`, `RestClientConfig`, etc.) — sin un test de contexto (`@SpringBootTest`) que verifique que la aplicación arranca correctamente con el *wiring* de beans real.

## 3. Estado real de la regla de cobertura del 80%

La regla `jacocoTestCoverageVerification` (mínimo 80% de instrucciones) está **configurada para todos los subproyectos** (`main.gradle`, aplicada en `subprojects { ... }`), con exclusiones explícitas de clases "no lógicas" (`*Mapper*`, `*Dto*`, `*Request`, `*Response`, `*Entity*`, `*Repository`, `config.*`, `MainApplication`, etc.).

Dado que solo `domain/usecase` tiene pruebas, y dentro de ese módulo la cobertura cubre 2 de las 8 clases (`CreateReportJobUseCase`, `MspiPortadaTemplateFiller`), es altamente probable que:

- Los módulos `api-rest`, `jpa-repository`, `rest-consumer`, `common`, `model` y `app-service` **no alcancen el 80%** de cobertura de instrucciones (varios directamente en 0%, al no tener ninguna clase de prueba).
- El propio módulo `usecase` probablemente tampoco alcance el 80% agregado, dado que clases con lógica sustancial (`ProcessReportJobUseCase`, `CreateComparativeReportJobUseCase`, `DownloadReportJobUseCase`, `ReportDocumentService`, `LibreOfficePdfConverter`) no tienen ejercicio directo por pruebas.

No fue posible ejecutar `./gradlew check` ni `./gradlew jacocoMergedReport` durante la elaboración de este documento (fuera del alcance de un análisis estático de código); esta conclusión se basa en la ausencia verificada de archivos de prueba, no en un reporte de cobertura generado. Se documenta como **hallazgo de riesgo**: el pipeline de build tiene una barrera de calidad configurada (`check.dependsOn jacocoTestCoverageVerification`) que, de ejecutarse tal como está, muy probablemente **fallaría** el build para la mayoría de los módulos de este microservicio.

## 4. Ejecución de pruebas — comandos reales

Documentados en el propio `README.md` del microservicio:

```bash
./gradlew.bat :app-service:compileJava
./gradlew.bat :usecase:test
./gradlew.bat test
```

`./gradlew.bat :usecase:test` ejecuta específicamente las 2 clases descritas en §2 (único módulo con pruebas). `./gradlew.bat test` ejecutaría la tarea `test` en todos los subproyectos configurados, la mayoría sin ninguna clase que recolectar (JUnit reportaría 0 pruebas ejecutadas en esos módulos, sin que eso constituya un fallo por sí mismo — a diferencia de la verificación de cobertura, que sí puede fallar).

## 5. Ausencia de pipeline CI/CD para este microservicio

A diferencia de otros microservicios del repositorio contenedor (`ms_iam`, `ms_org`, `ms_catalog`, `ms_evidence`, `ms_assessment`, cada uno con su propio `bitbucket-pipelines.yml`), **`ms_reporting` no tiene un archivo `bitbucket-pipelines.yml`** en su raíz. Esto significa que, a la fecha de este documento, no existe evidencia de que las pruebas (ni siquiera el `assemble` sin pruebas que sí ejecutan los demás microservicios en CI) se ejecuten automáticamente en ningún pipeline para este repositorio — la validación depende enteramente de la ejecución manual local de `./gradlew test`/`check` por parte del desarrollador. Ver `06-Implementacion-Despliegue.md` para el detalle de esta brecha.

## 6. Recomendaciones (no implementadas, quedan fuera del alcance actual)

- Agregar pruebas unitarias para `ProcessReportJobUseCase` mockeando los 4 gateways y `ReportDocumentService`, cubriendo al menos: transición `PENDING→RUNNING→COMPLETED`, transición a `FAILED` ante excepción del generador, y el caso de idempotencia (job ya `COMPLETED`).
- Agregar pruebas para `CreateComparativeReportJobUseCase` cubriendo las 3 reglas de negocio explícitas (`#116`).
- Agregar al menos una prueba de *slice* MVC (`@WebMvcTest` con `@AutoConfigureMockMvc` y JWT simulado vía `spring-security-test`, ya declarado como dependencia de test en `api-rest/build.gradle` pero sin uso actual) para verificar los códigos de estado HTTP de `ReportJobApi`.
- Crear (o replicar desde otro microservicio del repositorio) un `bitbucket-pipelines.yml` que al menos ejecute `./gradlew clean assemble` en CI, y evaluar si conviene incorporar `test`/`check` dado el estado actual de cobertura.
