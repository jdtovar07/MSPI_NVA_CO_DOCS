# ms_iam — Pruebas

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_iam` |
| Fecha del documento | 2026-08-18 |
| Alcance | Estrategia de pruebas real del microservicio `ms_iam`: frameworks, estructura, tipos de prueba evidenciados y configuración de cobertura |

---

## 1. Frameworks de prueba (verificados en `build.gradle`)

| Framework / librería | Versión | Uso | Módulo(s) |
|---|---|---|---|
| JUnit 5 (Jupiter) | gestionada por BOM Spring Boot 4.0.2; `test { useJUnitPlatform() }` en `main.gradle` | Motor de pruebas para todos los módulos | todos |
| `spring-boot-starter-test` | gestionada por BOM (incluye JUnit 5, Mockito, AssertJ, Spring Test) | Pruebas unitarias y de contexto | todos (`testImplementation` declarada en `main.gradle` para todos los subproyectos) |
| `spring-boot-starter-webmvc-test` | 4.0.2 (explícita) | Utilidades de prueba para capa web (MockMvc) | `api-rest` |
| `spring-security-test` | gestionada por BOM | Simular contexto de seguridad/JWT en pruebas de controladores | `api-rest`, `app-service` |
| Mockito (vía `spring-boot-starter-test`) | gestionada por BOM | *Mocking* de gateways/puertos en pruebas de caso de uso y de servicio | todos los módulos con lógica (`usecase`, `service`, `jpa-repository`, `rest-consumer`, `api-rest`) |
| `mockwebserver` (OkHttp) | 5.3.2 | Simular respuestas HTTP de Keycloak en pruebas de `rest-consumer` | `rest-consumer` |
| `archunit` | 1.4.1 | Declarada como dependencia de prueba en `app-service`, pensada para verificar reglas de arquitectura (p. ej. que el dominio no dependa de infraestructura) | `app-service` |

## 2. Estructura de carpetas de test (real, verificada en el repositorio)

```
domain/usecase/src/test/java/co/com/mspi/usecase/
├── login/LoginUseCaseTest.java
├── totp/TotpStatusUseCaseTest.java
├── totp/TotpVerifyUseCaseTest.java
└── user/GetUsersUseCaseTest.java

infrastructure/driven-adapters/jpa-repository/src/test/java/co/com/mspi/jpa/
├── adapter/AuthAuditAdapterTest.java
└── config/JpaConfigTest.java

infrastructure/driven-adapters/rest-consumer/src/test/java/co/com/mspi/consumer/
├── adapter/KeycloakAuthAdapterTest.java
├── mapper/UserInfoMapperTest.java
└── utils/ValidatorsTest.java

infrastructure/driven-adapters/service/src/test/java/co/com/mspi/service/
└── LoginServiceTest.java

infrastructure/driven-adapters/brevo-sender/src/test/java/co/com/mspi/brevo/
└── BrevoEmailAdapterTest.java

infrastructure/entry-points/api-rest/src/test/java/co/com/mspi/api/
├── auth/AuthApiTest.java
├── config/CorsConfigTest.java
├── config/SecurityHeadersFilterTest.java
├── config/TraceIdFilterTest.java
├── exception/GlobalExceptionHandlerTest.java
├── mapper/AuthApiMapperTest.java
├── roles/RolesApiTest.java
├── users/UsersApiTest.java
└── users/mapper/UsersApiMapperTest.java

infrastructure/helpers/common/src/test/java/co/com/mspi/common/
├── exception/ExceptionsTest.java
└── mapper/ApiResponseMapperTest.java
```

En total se identificaron **21 clases de prueba** distribuidas en 7 de los 9 módulos del proyecto. Los módulos `domain/model` (`:model`) y `applications/app-service` (`:app-service`, salvo el marcador `.gitignore` en su carpeta de test) **no tienen pruebas propias** en el repositorio: `:model` por ser solo POJOs/interfaces sin lógica, y `:app-service` porque su contenido (configuración de wiring, `MainApplication`) se excluye explícitamente del análisis de cobertura (`sonar.exclusions`) y de las reglas de JaCoCo (ver §4).

## 3. Tipos de prueba evidenciados

### 3.1 Pruebas unitarias de casos de uso (`domain/usecase`)

Prueban la lógica de orquestación del caso de uso de forma aislada, con el gateway (puerto) mockeado con Mockito — sin contexto de Spring. Ejemplo de patrón observado en `LoginUseCaseTest`, `TotpStatusUseCaseTest`, `TotpVerifyUseCaseTest`, `GetUsersUseCaseTest`: instanciación directa del caso de uso con un mock del gateway inyectado por constructor.

### 3.2 Pruebas unitarias de adaptadores de servicio (`infrastructure/driven-adapters/service`)

`LoginServiceTest` prueba las tres ramas de resultado (`LoginSuccess`, `LoginFailed`, `LoginInactive`) y la regla de negocio de `must_change_password`, mockeando `KeycloakAuthGateway`, `AuditAuthGateway` y `UserPersistenceGateway`.

### 3.3 Pruebas de adaptadores de persistencia (`jpa-repository`)

`AuthAuditAdapterTest` y `JpaConfigTest` verifican el comportamiento del adaptador de auditoría y de la configuración de conexión a base de datos (probablemente contra H2 en memoria dado que es el motor de test por defecto según `application.yaml`).

### 3.4 Pruebas de clientes REST salientes (`rest-consumer`)

`KeycloakAuthAdapterTest` usa **MockWebServer** (OkHttp) para simular respuestas reales del *token endpoint* de Keycloak (incluyendo casos de error como `account is not enabled` / `account is not fully set up`), verificando el mapeo correcto a `LoginResult`. `UserInfoMapperTest` y `ValidatorsTest` prueban mapeo de claims y validadores de formato (`EmailValidator`, `NameValidator`, `UserIdValidator`) de forma puramente unitaria.

### 3.5 Pruebas de controladores REST (`api-rest`)

`UsersApiTest`, `AuthApiTest`, `RolesApiTest` usan **MockMvc en modo standalone** (`MockMvcBuilders.standaloneSetup(...)`, confirmado en el código de `UsersApiTest`) con los casos de uso mockeados vía `@Mock`/`@InjectMocks` de Mockito (`MockitoExtension`). Esto significa que **no se levanta el contexto completo de Spring** (no son pruebas `@SpringBootTest` de extremo a extremo): se prueba el controlador de forma aislada, verificando serialización JSON (`jsonPath`), códigos de estado HTTP y delegación correcta a los casos de uso. `GlobalExceptionHandlerTest` prueba el mapeo de cada excepción de dominio a su código HTTP correspondiente. `CorsConfigTest`, `SecurityHeadersFilterTest`, `TraceIdFilterTest` prueban configuración transversal HTTP de forma unitaria/aislada.

### 3.6 Pruebas de mapeadores y utilidades (`common`, `mapper`)

`ApiResponseMapperTest`, `ExceptionsTest`, `AuthApiMapperTest`, `UsersApiMapperTest` son pruebas unitarias puras sobre lógica de transformación de datos, sin dependencias externas.

### 3.7 Ausencias explícitas

- **No se encontraron pruebas de integración con `@SpringBootTest`** (contexto completo de Spring Boot levantado) en ninguno de los módulos revisados; el enfoque observado es de pruebas unitarias/de "rebanada" (slice) con *mocks*, no de integración real contra H2/PostgreSQL levantando el contenedor de Spring.
- **No se encontraron pruebas end-to-end (E2E)** contra un Keycloak real ni contra contenedores Docker (no hay evidencia de Testcontainers en ningún `build.gradle`).
- **No se encontró una clase de prueba ArchUnit concreta** pese a que la dependencia `archunit:1.4.1` está declarada en `app-service/build.gradle`; esto sugiere que la verificación automática de reglas arquitectónicas (p. ej. "el dominio no debe depender de Spring") está planeada/parcialmente preparada pero no implementada aún, o fue removida. Se declara explícitamente esta discrepancia entre dependencia declarada y prueba ausente.
- **No se encontró carpeta `src/test/resources`** con `application-test.yaml` específico; las pruebas que requieren configuración parecen depender de los valores por defecto de `application.yaml` (H2 en memoria).

## 4. Cobertura de código (JaCoCo) y mutation testing (Pitest)

Configurados a nivel del `main.gradle` raíz para **todos los subproyectos** (`subprojects { ... }`):

- **JaCoCo 0.8.14** — genera reporte XML/HTML por módulo (`jacocoTestReport`, encadenado automáticamente tras `test` vía `test.finalizedBy(...)`) y un **reporte fusionado** (`jacocoMergedReport`) que agrega todos los módulos para consumo de SonarQube (`sonar.coverage.jacoco.xmlReportPaths = build/reports/jacocoMergedReport/jacocoMergedReport.xml`).
- **Umbral mínimo obligatorio de cobertura: 80%** de instrucciones cubiertas (`INSTRUCTION` / `COVEREDRATIO` ≥ `0.80`), aplicado por `jacocoTestCoverageVerification`, que además está enlazado a la tarea `check` (`check.dependsOn jacocoTestCoverageVerification`) — es decir, **el build falla si la cobertura cae por debajo del 80%** en cualquier módulo, salvo en las clases explícitamente excluidas:
  - `co.com.mspi.MainApplication`
  - Clases `*Mapper*`
  - Clases `*Dto*` / `*DTO*` y paquetes `*.dto.*`
  - `co.com.mspi.jpa.entity.*` y clases `*Entity*`
  - `co.com.mspi.model.*` (el propio dominio de modelo queda fuera de la exigencia de cobertura, siendo POJOs sin lógica)
  - `co.com.mspi.config.*` y `co.com.mspi.api.config.*`
- **Pitest (mutation testing)** — plugin `info.solidsoft.pitest` (versión de plugin `1.19.0-rc.3`, versión de motor `1.22.0`), configurado con `targetClasses = ['co.com.mspi.*']`, 8 hilos, historial de mutaciones habilitado (`withHistory = true`), reportes XML/HTML, y agregación multi-módulo mediante una tarea custom `pitestReportAggregate` que concatena los `mutations.xml` de cada subproyecto en un único reporte consolidado (`build/reports/pitest/mutations.xml`) para SonarQube (`sonar.pitest.reportPaths`).
- **SonarQube** — plugin `org.sonarqube` versión `7.2.2.6593`, configurado a nivel de todo el proyecto multi-módulo (`sonar.modules`), consumiendo tanto el reporte JaCoCo fusionado como el de Pitest, lo que indica una estrategia de calidad centrada en un *quality gate* de SonarQube (no verificado en este repositorio si existe `sonar-project.properties` adicional o si el análisis se ejecuta en CI, dado que `bitbucket-pipelines.yml` solo ejecuta `./gradlew clean assemble`, sin una etapa explícita de `sonar` o `check`).

## 5. Estrategia de pruebas recomendada (dado que CI no ejecuta pruebas automáticamente)

Se observa que el pipeline de CI (`bitbucket-pipelines.yml`) solo ejecuta `./gradlew clean assemble`, **sin invocar `test` ni `check`** antes del despliegue a Railway (ver `06-Implementacion-Despliegue.md`). Esto es una limitación real y verificable del proyecto: **las pruebas existen y están bien estructuradas, pero no se ejecutan automáticamente como gate de calidad en el pipeline actual.** Se recomienda:

1. Agregar una etapa explícita `./gradlew check` (que ya encadena `test` + `jacocoTestCoverageVerification` + `pitest` por la configuración de `main.gradle`) antes de `assemble`/`deploy` en `bitbucket-pipelines.yml`, para que el pipeline falle si la cobertura mínima del 80% no se cumple o si las pruebas fallan.
2. Publicar los artefactos de `build/reports/**` (ya declarados en el `step` `Build App`) hacia SonarQube en un paso dedicado, dado que la configuración de `sonar.gradle`/`build.gradle` ya está lista para ello pero no se invoca en el pipeline actual.
3. Incorporar pruebas de integración reales (p. ej. con Testcontainers + PostgreSQL) para los adaptadores JPA, dado que actualmente la verificación contra base de datos real no está evidenciada.
4. Completar o remover la dependencia declarada de ArchUnit, añadiendo al menos una prueba que verifique la regla de dependencia entre capas descrita en `03-Diseno.md` (dominio no depende de infraestructura), formalizando así una regla que hoy solo se cumple por convención/estructura de módulos.
