# ms_catalog — Pruebas

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_catalog` |
| Fecha del documento | 2026-08-19 |
| Alcance | Estrategia de pruebas real del microservicio `ms_catalog`: frameworks, estructura, tipos de prueba evidenciados y configuración de cobertura |

---

## 1. Frameworks de prueba declarados (verificados en `build.gradle`)

| Framework / librería | Versión | Declarado en | Uso real evidenciado |
|---|---|---|---|
| JUnit 5 (Jupiter) | gestionada por BOM Spring Boot 4.0.2; `test { useJUnitPlatform() }` en `main.gradle` | Todos los módulos (heredado de `main.gradle`) | Sí, en los 3 archivos de prueba existentes |
| `spring-boot-starter-test` | gestionada por BOM | Declarada en `main.gradle` para todos los subproyectos | Sí (JUnit 5, Mockito, AssertJ) |
| `spring-security-test` | gestionada por BOM | `app-service/build.gradle` | No se encontró ninguna clase de prueba que la utilice |
| `archunit` | 1.4.1 | `app-service/build.gradle` (`testImplementation 'com.tngtech.archunit:archunit:1.4.1'`) | **No se encontró ninguna clase de prueba ArchUnit** pese a la dependencia declarada |
| `object-mapper` (reactivecommons.utils) | 0.1.0 | `jpa-repository/build.gradle` (`testImplementation`) | No se encontró ninguna clase de prueba en el módulo `jpa-repository` que la utilice |
| Mockito (vía `spring-boot-starter-test`) | gestionada por BOM | Todos los módulos | Sí, en `TraceIdFilterTest` (`@ExtendWith(MockitoExtension.class)`, `@Mock`) |

## 2. Estructura de carpetas de test (real, verificada en el repositorio)

```
infrastructure/entry-points/api-rest/src/test/java/co/com/mspi/api/
├── config/CorsConfigTest.java
├── config/TraceIdFilterTest.java
└── exception/GlobalExceptionHandlerTest.java
```

**En total se identificaron 3 clases de prueba en todo el repositorio**, las 3 concentradas en el módulo `:api-rest`. Los 5 módulos restantes (`:model`, `:usecase`, `:common`, `:jpa-repository`, `:app-service`) **no tienen ninguna clase de prueba propia**:

- `:model` — sin lógica, solo POJOs (`@Data @Builder`); coherente con la ausencia de pruebas.
- `:usecase` — **contiene los 17 casos de uso con la única lógica de negocio real del microservicio** (resolución de plantilla activa, filtrado por `controlType`, etc.) y **no tiene ninguna prueba unitaria**. Es la ausencia de cobertura más significativa del proyecto, dado que es la capa que concentra las reglas de negocio documentadas en `02-Analisis.md` §3.
- `:common` — DTOs y excepciones compartidas, sin pruebas propias en este repositorio (a diferencia de `ms_iam`, que sí las tiene para el mismo módulo).
- `:jpa-repository` — contiene `CatalogJpaAdapter` (696 líneas, con parseo manual de JSON y lógica de ensamblado de relaciones en memoria) **sin ninguna prueba**, pese a ser el componente con más lógica no trivial del microservicio (parsers `extractJsonInt`, `parseStringListJson`, indexación de mapas, valores de repliegue).
- `:app-service` — configuración de arranque (`SecurityConfig`, `InfisicalConfig`, `DBCredentialConfig`, `UseCaseConfig`) sin pruebas; consistente con la exclusión de `co.com.mspi.config.*` de las reglas de cobertura de JaCoCo (ver §4).

## 3. Tipos de prueba evidenciados

### 3.1 `CorsConfigTest` (3 pruebas)

Instancia `CorsConfig` directamente (sin contexto Spring) y verifica que `corsFilter(origins)` construye un `FilterRegistrationBean<CorsFilter>` no nulo con el orden `Ordered.HIGHEST_PRECEDENCE`, para tres variantes de entrada: múltiples orígenes separados por coma, cadena vacía y un solo origen.

### 3.2 `TraceIdFilterTest` (4 pruebas)

Usa `@ExtendWith(MockitoExtension.class)` con `HttpServletRequest`, `HttpServletResponse` y `FilterChain` mockeados. Verifica:

- Que el filtro propaga el `X-Trace-Id` recibido por cabecera como atributo de request.
- Que genera un UUID nuevo cuando la cabecera está ausente o en blanco (`"   "`).
- Que siempre invoca `chain.doFilter(...)`.
- Que el valor queda **removido del MDC** después de que la cadena de filtros termina (evita fuga de contexto de logging entre peticiones concurrentes en el mismo hilo/pool).

### 3.3 `GlobalExceptionHandlerTest` (7 pruebas)

Instancia `GlobalExceptionHandler` directamente e invoca cada `@ExceptionHandler` de forma unitaria (sin `MockMvc`, sin contexto Spring), fijando el `MDC` con un `traceId` de prueba antes de cada caso (`@BeforeEach`) y limpiándolo después (`@AfterEach`). Cubre las 6 excepciones manejadas (incluyendo las 3 que, según `04-Desarrollo.md` §5, no tienen invocación real desde el dominio de `ms_catalog`: `UserAlreadyExistsException`, `IamServiceException`, `BusinessRulesOnFieldsException` no se prueba explícitamente pero sí las otras 5) y valida código HTTP, código de error y mensaje por defecto cuando el mensaje de la excepción viene vacío.

### 3.4 Ausencias explícitas

- **No hay pruebas unitarias de los 17 casos de uso** (`domain/usecase/catalog/*`), pese a que concentran toda la lógica de negocio del microservicio (resolución de plantilla activa, filtrado por tipo de control, etc.).
- **No hay pruebas del adaptador de persistencia** (`CatalogJpaAdapter`), en particular de los parsers JSON manuales (`extractJsonInt`, `parseMaturityCritConfig`, `parseNistTemplateConfig`, `parseStringListJson`) que son la lógica más propensa a error silencioso del proyecto (un JSON mal formado no lanza excepción, simplemente retorna el valor por defecto).
- **No hay pruebas del controlador `CatalogApi`** con `MockMvc` (a diferencia de, por ejemplo, `ms_iam`, que sí prueba sus controladores en modo standalone).
- **No hay pruebas de `SecurityConfig`** (extracción de roles `realm_access`, filtro `InternalApiKeyFilter`), pese a que este último representa una vía de autenticación alterna no documentada en el README (ver `02-Analisis.md` §5).
- **No se encontraron pruebas de integración `@SpringBootTest`** ni evidencia de Testcontainers en ningún `build.gradle`.
- **No se encontró carpeta `src/test/resources`** con configuración específica de test (p. ej. `application-test.yaml`).
- **No se encontró la clase de prueba ArchUnit** pese a la dependencia declarada en `app-service/build.gradle`, misma discrepancia observada en el piloto `ms_iam`.

## 4. Cobertura de código (JaCoCo) y mutation testing (Pitest)

Configurados a nivel del `main.gradle` raíz para **todos los subproyectos** (`subprojects { ... }`), de forma idéntica al resto de microservicios del sistema MSPI:

- **JaCoCo 0.8.14** — reporte XML/HTML por módulo (`jacocoTestReport`, encadenado tras `test`) y reporte fusionado (`jacocoMergedReport`) para SonarQube.
- **Umbral mínimo obligatorio de cobertura: 80%** de instrucciones (`INSTRUCTION`/`COVEREDRATIO` ≥ `0.80`), enlazado a `check` (`check.dependsOn jacocoTestCoverageVerification`), con exclusiones idénticas a las de `ms_iam`:
  - `co.com.mspi.MainApplication`
  - Clases `*Mapper*`, `*Dto*`/`*DTO*`, `*Request`, `*Response`, paquetes `*.dto.*`
  - `co.com.mspi.jpa.entity.*`, `*Entity*`, `co.com.mspi.jpa.repository.*`, `*Repository`
  - `co.com.mspi.model.*` (el dominio de modelo completo queda fuera de la exigencia)
  - `co.com.mspi.config.*`, `co.com.mspi.api.config.*`
  - `co.com.mspi.common.dto.*`, `co.com.mspi.common.exception.*`

  **Dado que estas exclusiones cubren la práctica totalidad de las clases sin prueba** (entidades, repositorios, DTOs, modelo de dominio y configuración), y que el módulo `:usecase` —que sí cuenta para cobertura y no tiene exclusión— **no tiene ninguna prueba**, el build de `ms_catalog` con `./gradlew check` fallaría hoy la verificación del 80% en el módulo `:usecase` si se ejecutara (no verificado en este análisis por no ejecutar el build; se infiere de la ausencia total de pruebas en ese módulo).
- **Pitest (mutation testing)** — plugin `info.solidsoft.pitest` (`1.19.0-rc.3`, motor `1.22.0`), `targetClasses = ['co.com.mspi.*']`, 8 hilos, agregación multi-módulo (`pitestReportAggregate`). Sin pruebas en `:usecase` y `:jpa-repository`, el análisis de mutaciones sobre esos módulos no tendría pruebas que "matar" mutantes.
- **SonarQube** — plugin `org.sonarqube` `7.2.2.6593`, configurado a nivel de todo el proyecto multi-módulo, consumiendo JaCoCo y Pitest fusionados.

## 5. Estrategia de pruebas recomendada

El pipeline de CI (`bitbucket-pipelines.yml`) solo ejecuta `./gradlew clean assemble`, **sin invocar `test` ni `check`** (ver `06-Implementacion-Despliegue.md`), por lo que la ausencia casi total de pruebas descrita arriba no bloquea hoy el despliegue. Se recomienda, en orden de impacto:

1. **Priorizar pruebas unitarias de `domain/usecase/catalog/*`**: es la capa con reglas de negocio reales (resolución de plantilla activa, filtrado condicional por `controlType`) y actualmente 0% cubierta; el patrón (constructor con gateway mockeado, sin contexto Spring) es directo de aplicar siguiendo el mismo enfoque usado en `ms_iam` (`LoginUseCaseTest`, etc.).
2. **Probar `CatalogJpaAdapter`**, en particular los parsers de JSON manual (`extractJsonInt`, `parseMaturityCritConfig`, `parseNistTemplateConfig`, `parseStringListJson`) con casos límite: JSON `null`, vacío, mal formado, claves ausentes — dado que hoy fallan silenciosamente a un valor por defecto sin ninguna prueba que lo confirme.
3. **Agregar pruebas `MockMvc` de `CatalogApi`** (siguiendo el patrón standalone usado en `ms_iam`) para verificar serialización JSON, códigos de estado y delegación correcta a los 17 casos de uso.
4. **Agregar una etapa `./gradlew check`** en `bitbucket-pipelines.yml` antes del despliegue a Railway, para que el pipeline falle si la cobertura mínima no se cumple — actualmente no aplicaría dado el estado real de cobertura, por lo que este paso debería ir acompañado de los puntos 1–3.
5. **Probar `InternalApiKeyFilter` y la extracción de roles de `SecurityConfig`**, dado que son la superficie de autenticación/autorización completa del microservicio y no tienen ninguna prueba.
6. Completar o remover la dependencia declarada de ArchUnit y de `object-mapper`, ambas sin uso real, para reducir superficie de dependencias no ejercitadas.
