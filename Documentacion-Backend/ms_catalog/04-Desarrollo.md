# ms_catalog — Desarrollo

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_catalog` |
| Fecha del documento | 2026-08-19 |
| Alcance | Implementación real del microservicio: librerías, patrones y funcionalidades concretas verificadas en el código |

---

## 1. Punto de entrada y arranque

`applications/app-service/src/main/java/co/com/mspi/MainApplication.java` es la clase `@SpringBootApplication` estándar (excluida del análisis Sonar vía `sonar.exclusions`). El arranque depende de dos precondiciones estrictas codificadas en `@Configuration` beans:

- `InfisicalConfig` (implementa `BeanFactoryPostProcessor` + `ApplicationContextAware`): si `INFISICAL_SITE_URL`, `INFISICAL_PROJECT_ID` e `INFISICAL_ENVIRONMENT` no están todos presentes, o falta credencial (`INFISICAL_CLIENT_ID`+`INFISICAL_CLIENT_SECRET` o `INFISICAL_ACCESS_TOKEN`), simplemente **no carga secretos** (no falla el arranque) — retorna silenciosamente. Si están presentes, agrega los secretos de Infisical como `MapPropertySource` de mayor prioridad (`addFirst`), de modo que placeholders como `${DB_CREDENTIAL}` se resuelven con los valores obtenidos.
- `DBCredentialConfig.dbSecret(Environment)`: **sí falla el arranque** (`IllegalStateException`) si la propiedad `DB_CREDENTIAL` no está presente tras el paso anterior. Parsea el JSON con `ObjectMapper` (Jackson) a `DBCredential` (host/puerto/nombre/usuario/password), construye la URL JDBC (`cred.toJdbcUrl()`) y expone un bean `DBSecret` consumido por `JpaConfig` (módulo `jpa-repository`). No existe *fallback* a H2 ni a ninguna base de datos embebida.

Esto implica que **`ms_catalog` no puede arrancar en local sin un `DB_CREDENTIAL` válido** (JSON), a diferencia de microservicios como `ms_iam` que sí declaran H2 en memoria para desarrollo.

## 2. Wiring de casos de uso (`UseCaseConfig`)

En lugar de anotar los 17 casos de uso con `@Component`/`@Service` (lo que introduciría una dependencia de Spring en `domain/usecase`), `applications/app-service/.../config/UseCaseConfig.java` declara 16 métodos `@Bean` (uno de los 17, `GetActiveTemplateVersionUseCase`, se registra igual pero es además inyectado como dependencia de los otros 12 en sus propios métodos `@Bean`, por eso hay 16 declaraciones que inyectan explícitamente `GetActiveTemplateVersionUseCase getActiveTemplateVersionUseCase` como segundo parámetro cuando aplica). Patrón repetido:

```java
@Bean
public GetLeafControlCatalogUseCase getLeafControlCatalogUseCase(
        CatalogPersistenceGateway catalogPersistenceGateway,
        GetActiveTemplateVersionUseCase getActiveTemplateVersionUseCase) {
    return new GetLeafControlCatalogUseCase(catalogPersistenceGateway, getActiveTemplateVersionUseCase);
}
```

`domain/usecase/catalog/*.java` usa Lombok `@RequiredArgsConstructor` para generar el constructor con los campos `final` inyectados, manteniendo el código de caso de uso libre de imports de Spring.

## 3. Adaptador de persistencia (`CatalogJpaAdapter`)

Clase única (`infrastructure/driven-adapters/jpa-repository/.../adapter/CatalogJpaAdapter.java`, 696 líneas) que implementa los 26 métodos de `CatalogPersistenceGateway`, inyectando 16 repositorios Spring Data JPA (`@RequiredArgsConstructor`). Patrones observados:

- **Mapeo manual entidad → dominio** con métodos `toDomain(...)` sobrecargados por tipo de entidad (sin MapStruct ni ModelMapper en este módulo, a diferencia de otros microservicios del sistema que sí usan `mapstruct` — no hay dependencia de MapStruct en `jpa-repository/build.gradle`).
- **Resolución de relaciones sin `JOIN` SQL**: para NIST (mapeos y filas Ciber) se cargan primero *todas* las funciones y subcategorías con `findAll()` y se indexan en `HashMap<UUID, Entity>` (`indexFunctionsById`, `indexSubcategoriesById`) antes de recorrer la colección principal y enriquecerla. Esto es aceptable dado el volumen bajo de funciones/subcategorías NIST (**6 funciones CSF 2.0** incl. GV, más categorías 1.1 y 22 de CSF 2.0), pero no escalaría a catálogos grandes.
- **Plantillas concurrentes**: el seed publica `template_version` **v1** y **v2**; `GET /catalog/template-versions/active` resuelve la de `status=PUBLISHED` con `published_at` más reciente (v2). Los clientes deben crear evaluaciones nuevas contra v2 para obtener PHVA 56/16/14/14 y NIST con Gobernar.
- **Evita N+1 en requisitos de madurez** con un único query `IN` adicional (`findByRequirementIdInOrderByLevelAsc(reqIds)`) para traer los umbrales de todos los requisitos encontrados, en vez de un query por requisito.
- **Parser JSON manual escrito a mano** (`extractJsonInt`, `extractJsonIntOptional`, `parsePhvaJson`, `parseStringListJson`, `parseMaturityCritConfig`, `parseNistTemplateConfig`) que busca subcadenas `"clave":` dentro del `String` JSON crudo devuelto por Hibernate para las columnas `JSONB`, en lugar de usar `ObjectMapper` (que sí está disponible como dependencia transitiva de Spring Boot). Es funcional para los formatos actuales pero frágil: no tolera JSON anidado arbitrario, comentarios, ni claves con nombres que sean substring de otras claves sin las comillas de delimitación exacta.
- **Valores de repliegue (*fallback*) embebidos como constantes de clase** cuando la columna `JSONB` es `NULL` (`DEFAULT_PHVA_COMPONENT_VALUES`, `defaultMaturityTemplateConfig()`, `defaultNistTemplateConfig()`), evitando `NullPointerException` aguas abajo en el mapeo a `Response`.

## 4. Capa API REST (`CatalogApi`)

- Único `@RestController` del microservicio, `@RequestMapping("/catalog")`, `@RequiredArgsConstructor` con 16 casos de uso inyectados (el mismo conteo que `UseCaseConfig`, dado que `GetActiveTemplateVersionUseCase` se usa también directamente en `getActiveTemplateVersion()`).
- Todos los métodos siguen el mismo patrón de 4 líneas: invocar el caso de uso → mapear con `CatalogApiMapper` → envolver con `ApiResponseMapper.success(traceId, data)` → `ResponseEntity.ok(...)`.
- El `traceId` de la respuesta (`meta.traceId`) se genera **por endpoint** con `UUID.randomUUID().toString()` en cada método de `CatalogApi`, independientemente del `X-Trace-Id` de la petición gestionado por `TraceIdFilter` (MDC). Es decir, existen **dos IDs de trazabilidad distintos** en la misma respuesta exitosa: el `X-Trace-Id` HTTP (correlación de logs de la petición) y el `meta.traceId` del cuerpo `CorrectResponse` (generado ad-hoc en el controlador). En cambio, `GlobalExceptionHandler` sí reutiliza el `traceId` de `TraceIdFilter` vía `MDC.get(TraceIdFilter.TRACE_ID_MDC_KEY)` para las respuestas de error, por lo que la coherencia entre `X-Trace-Id` y `meta.traceId` **solo se da en el camino de error**, no en el de éxito.
- Comentarios Javadoc en varios métodos referencian directamente historias de usuario del proyecto de grado (`HU-CFG-02`, `HU-AR-01`, `HU-DIAG-01`, `HU-ADM-01..04`, `HU-PHVA-01..05`, `HU-MAD-01..05`, `HU-CIB-01..03`), útil trazabilidad entre código y especificación funcional.

## 5. Manejo de errores (`GlobalExceptionHandler`, `:common`)

`@RestControllerAdvice` centralizado con 6 `@ExceptionHandler`:

| Excepción | HTTP | Código | Uso real en `ms_catalog` |
|---|---|---|---|
| `ResourceNotFoundException` | 404 | `CODE_NOT_FOUND` | Sí — plantilla activa no encontrada |
| `BusinessRulesOnFieldsException` | 400 | `CODE_BUSINESS_RULES` | No se encontró invocación real en `domain/usecase` de `ms_catalog` (excepción heredada del módulo `:common` compartido) |
| `UserAlreadyExistsException` | 409 | `CODE_USER_ALREADY_EXISTS` | No — no hay gestión de usuarios en `ms_catalog`; residuo del módulo `:common` compartido (probablemente diseñado originalmente para `ms_iam`) |
| `IamServiceException` | 502 | `CODE_IAM_SERVICE_ERROR` | No — `ms_catalog` no llama a `ms_iam`; mismo origen que el anterior |
| `MethodArgumentNotValidException` | 400 | `CODE_VALIDATION` | No se encontró uso de `@Valid`/Bean Validation en `CatalogApi` (todos los parámetros son `@RequestParam` simples) |
| `DomainException` | 500 | `CODE_INTERNAL_ERROR` | Disponible como manejador genérico de última instancia |

Este hallazgo confirma que el módulo `:common` (`infrastructure/helpers/common`) fue **replicado tal cual desde un microservicio con más responsabilidades de negocio** (probablemente `ms_iam`, dado que declara excepciones de dominio de identidad), y `ms_catalog` solo ejercita en la práctica `ResourceNotFoundException` (única invocada realmente desde un caso de uso de este microservicio) y el manejador genérico `DomainException`.

## 6. Seguridad implementada

- **`SecurityConfig`**: `@EnableWebSecurity` + `@EnableMethodSecurity`, `SecurityFilterChain` con CSRF deshabilitado (API stateless sin cookies de sesión), `sessionCreationPolicy(STATELESS)`, rutas públicas explícitas (`/actuator/health`, `/actuator/info`, `/error`) y el resto `authenticated()`.
- **Decodificador JWT propio** (`jwtDecoder()` bean): usa `RestTemplate` con timeouts explícitos (conexión 15s, lectura 30s) para resolver el JWK set, ya sea desde `JWT_JWK_SET_URI` directo (si está configurado) o resolviendo el *issuer* (`JWT_ISSUER_URI`) con `JwtValidators.createDefaultWithIssuer(issuer)`.
- **Extracción de roles de Keycloak**: `extractRealmRoles(Jwt)` lee el claim `realm_access.roles` (estructura estándar de Keycloak) y los transforma en `ROLE_<rol>`; además siempre añade `ROLE_USER` a cualquier JWT válido (`jwtAuthenticationConverter`).
- **`InternalApiKeyFilter`**: filtro adicional de autenticación S2S por cabecera `X-Internal-Api-Key`, antepuesto al filtro Bearer estándar (ver hallazgo detallado en `02-Analisis.md` §5 y `03-Diseno.md` §6).
- No hay autorización granular por rol (`@PreAuthorize`, `hasRole(...)`) en `CatalogApi`: cualquier JWT autenticado (con `ROLE_USER` mínimo garantizado) puede leer todos los endpoints.

## 7. Configuración multi-entorno (`application.yaml`)

Único archivo de configuración (no se encontraron `application-dev.yaml`/`application-prod.yaml` ni perfiles Spring activos por convención de nombre). Variables externalizadas con valores por defecto donde aplica:

```yaml
server:
  port: ${SERVER_PORT:8085}
cors:
  allowed-origins: ${CORS_ALLOWED_ORIGINS}
spring:
  application:
    name: catalog
  sql:
    init:
      mode: never
  jpa:
    hibernate:
      ddl-auto: none
spring.security.oauth2.resourceserver.jwt.issuer-uri: ${JWT_ISSUER_URI:https://keycloak-production-4a95.up.railway.app/realms/iam}
spring.security.oauth2.resourceserver.jwt.jwk-set-uri: ${JWT_JWK_SET_URI:}
internal-api:
  internal-api-key: ${INTERNAL_API_KEY:}
```

Nótese que el valor por defecto de `JWT_ISSUER_URI` apunta a una URL de Railway de producción (no a `localhost`), lo cual significa que si esa variable no se define explícitamente en un entorno local, el servicio validará JWT contra el Keycloak de producción del proyecto.

## 8. Funcionalidades concretas implementadas (resumen operativo)

1. Resolución de plantilla de instrumento activa con *fallback* automático en 12 de 17 endpoints.
2. Árbol de controles ISO 27001 Anexo A navegable (`control-catalog-tree`) y su proyección plana de hojas calificables (`control-catalog-leaves`), ambos filtrables por rama `ADMIN`/`TECH`.
3. Reglas de validación por control (evidencia/brecha/recomendación) para que consumidores como `ms_assessment` sepan qué campos exigir al evaluador.
4. Configuración cuantitativa del modelo de calificación (pesos PHVA, umbrales de madurez, metas NIST) editable únicamente vía SQL directo sobre `template_version`, con valores de repliegue en código para no romper a los consumidores si la configuración no está definida.
5. Trazabilidad HTTP (`X-Trace-Id`) y logging estructurado de cada petición (`TraceIdFilter`) independiente del `traceId` de negocio en el cuerpo de la respuesta.
6. Gestión de secretos por Infisical con arranque estricto si falta la credencial de base de datos.

## 9. Ausencias explícitas de desarrollo

- No hay uso de MapStruct, ModelMapper ni ningún generador de mapeo declarativo: todo el mapeo entidad↔dominio↔DTO es manual.
- No hay `@Cacheable` ni ninguna dependencia de caché en ningún módulo.
- No hay clientes REST salientes (`RestTemplate`/`WebClient`/Feign) hacia otros microservicios MSPI: `ms_catalog` no llama a `ms_iam`, `ms_org`, `ms_assessment` ni ningún otro servicio; es un productor puro de datos.
- No hay lógica de negocio de escritura (no hay `Save*UseCase`, `Update*UseCase` ni `Create*UseCase` en `domain/usecase`).
- No se encontró Bean Validation (`jakarta.validation`) activamente usada pese a que `spring-boot-starter-validation` está declarado como dependencia en `api-rest/build.gradle`.
