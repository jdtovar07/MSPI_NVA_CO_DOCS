# ms_org — Pruebas

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_org` |
| Fecha del documento | 2026-08-19 |
| Alcance | Estrategia de pruebas real del microservicio `ms_org`: frameworks, estructura, tipos de prueba evidenciados y configuración de cobertura |

---

## 1. Frameworks de prueba (verificados en `build.gradle`)

| Framework / librería | Versión | Uso | Módulo(s) |
|---|---|---|---|
| JUnit 5 (Jupiter) | gestionada por BOM Spring Boot 4.0.2; `test { useJUnitPlatform() }` en `main.gradle` | Motor de pruebas para todos los módulos | todos |
| `spring-boot-starter-test` | gestionada por BOM (incluye JUnit 5, Mockito, AssertJ, Spring Test) | Declarada globalmente en `main.gradle` para todos los subproyectos (`testImplementation`) | todos |
| `spring-security-test` | gestionada por BOM | Simular contexto de seguridad/JWT en pruebas de `api-rest` | `api-rest` (explícita en `build.gradle`) |
| Mockito (vía `spring-boot-starter-test`, `MockitoExtension`) | gestionada por BOM | *Mocking* de gateways/puertos y de casos de uso en pruebas de controlador | `usecase`, `api-rest` |
| `com.tngtech.archunit:archunit` | 1.4.1 (`testImplementation`) | Declarada en `app-service/build.gradle`, pensada para reglas de arquitectura | `app-service` (sin clase de prueba concreta encontrada) |
| `org.reactivecommons.utils:object-mapper` | 0.1.0 (`testImplementation`) | Declarada en `jpa-repository/build.gradle`; no se encontró una clase de prueba en ese módulo que la use | `jpa-repository` (dependencia sin prueba asociada) |

## 2. Estructura de carpetas de test (real, verificada en el repositorio)

```
domain/usecase/src/test/java/co/com/mspi/usecase/
├── location/
│   ├── GetCitiesByStateUseCaseTest.java
│   ├── GetCountriesUseCaseTest.java
│   └── GetStatesByCountryUseCaseTest.java
└── organization/
    ├── CreateOrganizationUseCaseTest.java
    ├── GetMyOrganizationUseCaseTest.java
    ├── GetOrganizationByIdUseCaseTest.java
    ├── GetOrganizationsUseCaseTest.java
    └── UpdateOrganizationUseCaseTest.java

infrastructure/entry-points/api-rest/src/test/java/co/com/mspi/api/
├── config/
│   ├── CorsConfigTest.java
│   └── TraceIdFilterTest.java
├── exception/GlobalExceptionHandlerTest.java
├── location/LocationApiTest.java
├── organization/
│   ├── OrganizationApiTest.java
│   └── mapper/OrganizationApiMapperTest.java
```

En total se identificaron **14 clases de prueba** distribuidas en 2 de los 6 módulos del proyecto (`:usecase` y `:api-rest`). Los módulos `:model` (POJOs/interfaces sin lógica), `:common`, `:jpa-repository` y `:app-service` **no tienen pruebas propias** en el repositorio, pese a que `:jpa-repository` declara una dependencia de test (`object-mapper`) sin usarla y `:app-service` declara `archunit` sin una prueba concreta — mismo patrón de discrepancia ya observado en `ms_iam`.

**Ausencia notable**: ninguno de los tres adaptadores que concentran lógica de infraestructura más sensible (`CreateOrganizationGatewayAdapter`, `IamGatewayAdapter`, `LocationCatalogAdapter`) tiene prueba unitaria, ya que residen en `applications/app-service`, el único módulo ejecutable sin carpeta `src/test`. Tampoco existe prueba para `OrganizationJpaAdapter` (módulo `:jpa-repository`), que es donde vive la regla de unicidad `(name, identifier)` y la lógica de `update` con conservación de campos no enviados.

## 3. Tipos de prueba evidenciados

### 3.1 Pruebas unitarias de casos de uso (`domain/usecase`)

Las 8 clases de test de `:usecase` siguen un patrón uniforme: `@ExtendWith(MockitoExtension.class)`, mock del gateway correspondiente vía `@Mock`, instanciación directa del caso de uso en `@BeforeEach` (sin contexto de Spring), y verificación tanto del valor retornado como de la interacción con el mock (`verify(gateway).metodo(...)`). Ejemplo: `CreateOrganizationUseCaseTest.executeReturnsResultFromGateway` verifica que el resultado del gateway se propague sin transformación y que `createWithLector` se invoque exactamente con el objeto de dominio recibido.

Los tests de `GetCitiesByStateUseCaseTest`, `GetCountriesUseCaseTest`, `GetStatesByCountryUseCaseTest` cubren, además del camino feliz, la rama de corte temprano (parámetro vacío/nulo → lista vacía sin invocar el gateway).

### 3.2 Pruebas de controladores REST (`api-rest`)

`OrganizationApiTest` y `LocationApiTest` **no usan `MockMvc`**: instancian el controlador directamente (`new OrganizationApi(...)`) con los 5 casos de uso mockeados vía `@Mock`, y llaman a los métodos Java del controlador de forma directa, verificando el `ResponseEntity` retornado (`HttpStatus`, cuerpo `CorrectResponse`) con aserciones JUnit estándar (`assertEquals`, `assertNotNull`, `assertTrue`) y `ArgumentCaptor` para inspeccionar el objeto de dominio construido a partir del DTO. Este enfoque es una prueba unitaria de la clase controladora, no una prueba de *slice* HTTP (no valida enrutamiento, *content negotiation*, serialización JSON real ni la cadena de filtros de seguridad) — a diferencia del patrón `MockMvcBuilders.standaloneSetup(...)` documentado en `ms_iam`.

`OrganizationApiMapperTest` prueba el mapeo estático DTO↔dominio de forma puramente unitaria, sin dependencias.

### 3.3 Pruebas de configuración transversal (`api-rest/config`)

`CorsConfigTest` y `TraceIdFilterTest` prueban de forma aislada la construcción del filtro CORS a partir de la propiedad `cors.allowed-origins` y el comportamiento de generación/propagación de `X-Trace-Id` (incluida la limpieza de `MDC` tras la petición), respectivamente.

### 3.4 Pruebas de manejo de errores

`GlobalExceptionHandlerTest` verifica que cada una de las 6 excepciones manejadas se traduzca al código HTTP y al `code` de `ErrorDetail` correcto, incluyendo el caso de `MethodArgumentNotValidException` con múltiples errores de campo.

### 3.5 Ausencias explícitas

- **No se encontraron pruebas de integración con `@SpringBootTest`** (contexto completo de Spring Boot levantado, ni siquiera con perfil de test) en ningún módulo.
- **No se encontraron pruebas end-to-end (E2E)** contra PostgreSQL real ni contra `ms_iam` real; no hay evidencia de Testcontainers en ningún `build.gradle`.
- **No se encontró una clase de prueba ArchUnit concreta** pese a que la dependencia está declarada en `app-service/build.gradle` — idéntica discrepancia a la ya documentada en `ms_iam`.
- **No hay pruebas para `OrganizationJpaAdapter`, `CreateOrganizationGatewayAdapter`, `IamGatewayAdapter` ni `LocationCatalogAdapter`** — es decir, la lógica de negocio más crítica del microservicio (unicidad, compensación transaccional, traducción de errores de `ms_iam`, degradación del catálogo externo) **no tiene cobertura de prueba automatizada verificable en el repositorio**, más allá de lo que ejercite indirectamente `GlobalExceptionHandlerTest` sobre las excepciones ya lanzadas.
- **No se encontró carpeta `src/test/resources`** en ningún módulo, ni `application-test.yaml`.
- **No hay pruebas de `SecurityConfig`** (mapeo de roles desde `realm_access.roles`, construcción del `JwtDecoder`) pese a que `spring-security-test` está declarada como dependencia de `api-rest`.

## 4. Cobertura de código (JaCoCo) y mutation testing (Pitest)

Configurados a nivel del `main.gradle` raíz, **idéntico** a la configuración de `ms_iam`, aplicado a todos los subproyectos:

- **JaCoCo 0.8.14** — reporte por módulo (`jacocoTestReport`, encadenado tras `test`) y reporte fusionado multi-módulo (`jacocoMergedReport`) para SonarQube.
- **Umbral mínimo obligatorio de cobertura: 80%** de instrucciones (`INSTRUCTION`/`COVEREDRATIO` ≥ `0.80`), enlazado a la tarea `check` (`check.dependsOn jacocoTestCoverageVerification`), con las mismas exclusiones de paquete que `ms_iam` (`MainApplication`, `*Mapper*`, `*Dto*`/`*DTO*`, `*Request`, `*Response`, `jpa.entity.*`, `jpa.repository.*`, `*Entity*`, `*Repository`, `model.*`, `config.*`, `api.config.*`, `common.dto.*`, `common.exception.*`).
- Dado que `OrganizationJpaAdapter`, `CreateOrganizationGatewayAdapter`, `IamGatewayAdapter` y `LocationCatalogAdapter` **no están excluidos** de esta verificación (no son `*Mapper*`, `*Entity*` ni `config.*`) y **no tienen pruebas propias**, si el `check` llegara a ejecutarse realmente en CI, es previsible que **el build fallaría por incumplimiento del umbral del 80%** en el módulo `:jpa-repository` y en las clases de adaptador de `app-service` — coherente con que el pipeline actual (ver `06-Implementacion-Despliegue.md`) tampoco invoca `check` ni `test`.
- **Pitest (mutation testing)** — misma configuración que `ms_iam` (`targetClasses = ['co.com.mspi.*']`, 8 hilos, `withHistory = true`, agregación multi-módulo vía `pitestReportAggregate`).
- **SonarQube** — plugin `org.sonarqube` 7.2.2.6593 configurado a nivel de todo el proyecto multi-módulo; sin evidencia de ejecución en el pipeline actual (`bitbucket-pipelines.yml` solo ejecuta `./gradlew clean assemble`).

## 5. Estrategia de pruebas recomendada

El pipeline de CI (`bitbucket-pipelines.yml`) solo ejecuta `./gradlew clean assemble`, **sin invocar `test` ni `check`** antes del despliegue a Railway (idéntico patrón a `ms_iam`, ver `06-Implementacion-Despliegue.md`). Recomendaciones fundamentadas en las brechas concretas detectadas:

1. **Priorizar pruebas para `OrganizationJpaAdapter`** (regla de unicidad `(name, identifier)`, comportamiento de `update` con campos parciales) y **para `CreateOrganizationGatewayAdapter`** (camino feliz y camino de rollback ante fallo de IAM), dado que son las dos piezas de mayor riesgo de negocio sin cobertura hoy.
2. **Agregar pruebas para `IamGatewayAdapter.toDomainException`**, dado que la lógica de distinción entre `UserAlreadyExistsException` (409) e `IamServiceException` (502) depende de parsear un JSON de respuesta ajeno (`ms_iam`) y hoy no está verificada; un cambio no coordinado en el formato de error de `ms_iam` rompería esta traducción sin que ninguna prueba lo detecte.
3. **Agregar una etapa explícita `./gradlew check`** en `bitbucket-pipelines.yml` antes de `assemble`/despliegue, asumiendo primero el trabajo del punto 1-2 para que el umbral de cobertura del 80% sea alcanzable sin inflar pruebas artificialmente.
4. **Migrar `OrganizationApiTest`/`LocationApiTest` a `MockMvc`** (real *slice* de controlador) si se desea verificar también serialización JSON, `@Valid` y la cadena de filtros de seguridad, ya que hoy solo se prueba la clase Java del controlador de forma aislada.
5. **Completar o remover la dependencia declarada de ArchUnit** en `app-service`, formalizando al menos una regla que valide que `:model` y `:usecase` no dependan de Spring/JPA — la separación existe hoy solo por convención de módulos, sin verificación automática.
