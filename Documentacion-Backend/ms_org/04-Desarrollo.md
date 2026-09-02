# ms_org — Desarrollo

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_org` |
| Fecha del documento | 2026-08-19 |
| Alcance | Implementación real: librerías, patrones de código y funcionalidades concretas verificadas en `ms_org` |

---

## 1. Convenciones de código observadas

- **Paquete base**: `co.com.mspi`, consistente con `ms_iam` (mismo grupo Java raíz para todos los microservicios MSPI).
- **Lombok** en todas las capas: `@Data`/`@Builder(toBuilder = true)` en modelos de dominio y entidades JPA, `@RequiredArgsConstructor` en casos de uso y adaptadores (inyección por constructor implícita, sin `@Autowired` explícito), `@Slf4j` para logging.
- **`toBuilder = true`** en `Organization` y `CorrectResponse`, usado para construir variantes parciales de un objeto existente (p. ej. `toSave = organization.toBuilder().id(id).status(status).build()` en `OrganizationJpaAdapter.save`).
- **Logging con prefijo de componente entre corchetes**, igual convención que `ms_iam`: `[ADAPTER][OrganizationJpa]`, `[ADAPTER][CreateOrganization]`, `[ADAPTER][IamGateway]`, `[FILTER][traceId]` — facilita filtrar logs por capa/componente.
- **Records de Java** para los value objects de ubicación (`CountryLocation`, `StateLocation`, `CityLocation`) — únicos modelos de dominio implementados como `record` en vez de clases Lombok, por ser inmutables y sin necesidad de builder.
- **Clases utilitarias con constructor privado**: `OrganizationApiMapper`, `ApiResponseMapper`, `CommonErrorConstants` siguen el patrón `private Clase() {}` + métodos `static`.

## 2. Funcionalidades implementadas (mapeo funcionalidad → clases)

### 2.1 Gestión CRUD de organizaciones

- **Controlador**: `OrganizationApi` (`infrastructure/entry-points/api-rest`), 5 endpoints (`create`, `list`, `getById`, `update`, `getMyOrganization`).
- **Mapeo DTO↔dominio**: `OrganizationApiMapper` (métodos estáticos `toDomain`, `toResponse`, `toPagedResponse`).
- **DTOs de entrada/salida**: `OrganizationRequest` (validación `@NotBlank` en 6 campos), `OrganizationResponse`, `PagedOrganizationsResponse`, `CreateOrganizationResponse`.
- **Persistencia**: `OrganizationJpaAdapter` implementa las 8 operaciones de `OrganizationPersistenceGateway` contra `OrganizationRepository` (Spring Data JPA) y `OrganizationContactRepository`.
- **Entidades JPA**: `OrganizationEntity` (`org.organization`), `OrganizationContactEntity` (`org.organization_contact`).

### 2.2 Orquestación de creación con IAM

- `CreateOrganizationGatewayAdapter` (paquete `co.com.mspi.organization` en `app-service`) implementa `CreateOrganizationGateway`, coordinando `OrganizationPersistenceGateway` (guardar) e `IamGateway` (aprovisionar usuario), con compensación manual en caso de fallo (ver `03-Diseno.md` §8.4).
- `IamGatewayAdapter` (paquete `co.com.mspi.iam`) implementa `IamGateway` con un `RestClient` calificado `@Qualifier("msIamRestClient")`, configurado en `IamRestClientConfig` con **propagación del JWT del usuario actual** como `Authorization: Bearer` hacia `ms_iam` (extraído de `SecurityContextHolder`, no de un *service account* separado).
- Traducción de errores de `ms_iam`: `IamGatewayAdapter.toDomainException` parsea el `ErrorResponse` JSON devuelto por `ms_iam`, y si el `code` es `DUPLICATE_EMAIL` lanza `UserAlreadyExistsException` (→ 409); cualquier otro caso, `IamServiceException` (→ 502). Si el cuerpo no es JSON parseable, usa el texto crudo (truncado a 300 caracteres) como mensaje.

### 2.3 Catálogo geográfico

- `LocationApi` expone 3 endpoints públicos, cada uno delega a su caso de uso correspondiente y mapea a *records* internos (`CountryItem`, `StateItem`, `CityItem`) anidados en el propio controlador.
- `LocationCatalogAdapter` (paquete `co.com.mspi.location` en `app-service`) implementa `LocationCatalogGateway` contra la API pública **Country State City**, usando un `RestClient` calificado `@Qualifier("countryStateCityRestClient")` (`CountryStateCityClientConfig`) con cabecera `X-CSCAPI-KEY`.
- Deserialización genérica con `ParameterizedTypeReference<List<Map<String, Object>>>` (sin DTOs tipados para la respuesta externa), y mapeo manual campo a campo (`getString(m, "iso2")`, etc.), tolerante a campos faltantes.

### 2.4 Transversales (`infrastructure/helpers/common` + `infrastructure/entry-points/api-rest/config`)

- **Envoltorio de respuesta uniforme**: `CorrectResponse`/`ErrorResponse`/`Meta`/`ErrorDetail`, construidos vía `ApiResponseMapper` (idéntico patrón a `ms_iam`).
- **Manejo global de errores**: `GlobalExceptionHandler` (`@RestControllerAdvice`) con 6 manejadores específicos (`ResourceNotFoundException`, `BusinessRulesOnFieldsException`, `UserAlreadyExistsException`, `IamServiceException`, `MethodArgumentNotValidException`, `DomainException`) — menor cantidad que en `ms_iam` (que declara 10), reflejando el catálogo de errores más acotado de este dominio.
- **Trazabilidad**: `TraceIdFilter` (`@Order(HIGHEST_PRECEDENCE + 1)`), genera o propaga `X-Trace-Id`, lo publica en `MDC` y registra inicio/fin de cada request con duración en milisegundos.
- **CORS**: `CorsConfig` construye un `CorsFilter` explícito a partir de `cors.allowed-origins` (variable `CORS_ALLOWED_ORIGINS`), permitiendo credenciales y todos los métodos HTTP relevantes.

## 3. Integración con gestión de secretos (Infisical)

`InfisicalConfig` (`app-service`) implementa `BeanFactoryPostProcessor` + `ApplicationContextAware` para inyectar los secretos de Infisical **antes** de que Spring resuelva el resto de `@Value`/`@ConfigurationProperties`, agregando un `MapPropertySource` de máxima prioridad (`addFirst`). Soporta dos formas de autenticación (par `INFISICAL_CLIENT_ID`/`INFISICAL_CLIENT_SECRET`, o `INFISICAL_ACCESS_TOKEN` directo), y es tolerante a ausencia de configuración (si faltan variables, simplemente no carga nada, sin fallar el arranque) — a diferencia de `DBCredentialConfig`, que sí es estricto y falla si `DB_CREDENTIAL` no aparece luego de esta carga.

`DBCredentialConfig` parsea el JSON de `DB_CREDENTIAL` en `DBCredential` (host/port/name/user/password) y construye la URL JDBC (`toJdbcUrl()`), exponiendo un bean `DBSecret` consumido por `JpaConfig` para construir el `HikariDataSource` manualmente.

## 4. Patrones de diseño identificados

| Patrón | Dónde se aplica |
|---|---|
| **Ports & Adapters (hexagonal)** | 4 interfaces de gateway en `:model`, implementadas por adaptadores en `:jpa-repository` y `app-service` |
| **Builder** | Todos los modelos de dominio y entidades JPA (Lombok `@Builder`) |
| **Mapper estático** | `OrganizationApiMapper` (API↔dominio), mapeo manual campo a campo dentro de `OrganizationJpaAdapter` (dominio↔entidad) |
| **Compensación manual (saga simplificada)** | `CreateOrganizationGatewayAdapter.createWithLector` — try/catch con rollback explícito, sin outbox ni mensajería |
| **Adapter con degradación controlada** | `LocationCatalogAdapter` — nunca propaga error de la API externa, retorna colecciones vacías |
| **Chain of Responsibility implícito (filtros servlet)** | `TraceIdFilter` → `CorsFilter` → cadena de seguridad de Spring |
| **Configuración externalizada por `@ConfigurationProperties`** | `AdapterProperties`, `AppLocationApiProperties`, `CorsProperties`, `JwtResourceServerProperties` |
| **Bean post-processing para secretos** | `InfisicalConfig` (`BeanFactoryPostProcessor`) |

## 5. Dependencias externas relevantes (por `build.gradle`)

| Dependencia | Versión | Módulo | Propósito |
|---|---|---|---|
| `spring-boot-starter-webmvc` | 4.0.2 (BOM) | `api-rest` | Controladores REST servlet |
| `spring-boot-starter-security` + `oauth2-resource-server` + `oauth2-jose` | 4.0.2 (BOM) | `api-rest`, `app-service` | Validación de JWT Keycloak, RBAC |
| `spring-boot-starter-validation` | 4.0.2 (BOM) | `api-rest` | Bean Validation (`@NotBlank`) |
| `spring-boot-starter-actuator` | 4.0.2 (BOM) | `api-rest` | `/actuator/health`, `/actuator/info` |
| `spring-boot-starter-data-jpa` | 4.0.2 (BOM) | `jpa-repository` | Repositorios Spring Data, Hibernate |
| `org.postgresql:postgresql` | gestionada por BOM | `jpa-repository`, `app-service` | Driver JDBC PostgreSQL (única BD soportada) |
| `com.infisical:sdk` | 3.0.2 | `app-service` | Cliente del gestor de secretos Infisical |
| `com.fasterxml.jackson.core:jackson-databind` | gestionada por BOM | `app-service` | Parseo de JSON de errores de `ms_iam` y de secretos |
| `spring-boot-devtools` | gestionada por BOM (`runtimeOnly`) | `app-service` | *Live reload* en desarrollo |
| `com.tngtech.archunit:archunit` | 1.4.1 (`testImplementation`) | `app-service` | Declarada para pruebas de arquitectura (sin prueba concreta implementada — ver `05-Pruebas.md`) |

## 6. Convenciones de nombrado de excepciones (módulo `:common`)

| Excepción | Extiende | Uso |
|---|---|---|
| `ResourceNotFoundException` | `DomainException` (implícito por jerarquía común) | Recurso no encontrado |
| `BusinessRulesOnFieldsException` | ídem | Violación de regla de negocio sobre campos |
| `UserAlreadyExistsException` | ídem | Correo duplicado reportado por `ms_iam` |
| `IamServiceException` | ídem, con constructor `(message, cause)` | Error de comunicación con `ms_iam` |
| `DomainException` | `RuntimeException` | Excepción base de dominio / red de seguridad genérica |

## 7. Observaciones de código relevantes para desarrollo futuro

- El comentario en `IamGatewayAdapter.createLectorUser` (`pw.toString(); // solo para no perder el valor, se envía por correo desde ms_iam`) evidencia que **`ms_org` recibe la contraseña temporal generada por `ms_iam` pero no la usa ni la muestra** — la notificación al usuario final ocurre enteramente del lado de `ms_iam` (vía Brevo, según `ms_iam`/`06-Implementacion-Despliegue.md`). Es una llamada sin efecto útil actualmente (`pw.toString()` sin asignar ni loguear el resultado), candidata a limpieza o a logging explícito.
- `LocationCatalogAdapter` no aplica *caching* sobre las respuestas de la API externa (cada request de país/estado/ciudad dispara una llamada HTTP saliente nueva); dado que el catálogo geográfico cambia con muy baja frecuencia, es candidato natural a una capa de caché (Spring Cache / Caffeine) no implementada hoy.
- No existe un módulo de pruebas para los tres adaptadores que viven en `app-service` (`CreateOrganizationGatewayAdapter`, `IamGatewayAdapter`, `LocationCatalogAdapter`) — coincide con la ausencia general de pruebas en `app-service` documentada también en `ms_iam`, pero aquí es más relevante porque concentra lógica de negocio real (compensación, traducción de errores), no solo *wiring*.
