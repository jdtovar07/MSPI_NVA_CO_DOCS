# ms_iam — Desarrollo

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_iam` |
| Fecha del documento | 2026-08-18 |
| Alcance | Descripción de la implementación real: tecnologías, estructura de código por capa, patrones aplicados y funcionalidades desarrolladas |

---

## 1. Tecnologías y librerías (consolidado de todos los `build.gradle`)

| Categoría | Librería | Versión | Módulo(s) |
|---|---|---|---|
| Runtime | Java (toolchain) | 21 | todos |
| Framework | Spring Boot | 4.0.2 (BOM vía `spring-boot-dependencies`) | todos |
| Web | `spring-boot-starter-webmvc` | gestionada por BOM | `api-rest`, `app-service` |
| Web (cliente) | `spring-boot-starter-web` | gestionada por BOM | `app-service` |
| Seguridad | `spring-boot-starter-security`, `spring-security-oauth2-resource-server`, `spring-security-oauth2-jose` | gestionada por BOM | `api-rest`, `app-service` |
| Persistencia | `spring-boot-starter-data-jpa` | gestionada por BOM | `jpa-repository` |
| BD desarrollo | `com.h2database:h2` | gestionada por BOM | `jpa-repository` (`runtimeOnly`, marcado `// TODO: remove this to use real database`) |
| BD producción | `org.postgresql:postgresql` | gestionada por BOM | `app-service` (`runtimeOnly`) |
| Observabilidad | `spring-boot-starter-actuator`, `micrometer-registry-prometheus` | gestionada por BOM | `api-rest` |
| Resiliencia | `io.github.resilience4j:resilience4j-spring-boot3` | 2.3.0 | `rest-consumer` |
| Validación | `spring-boot-starter-validation` | gestionada por BOM | `api-rest` |
| Serialización | `com.fasterxml.jackson.core:jackson-databind`, `tools.jackson.core:jackson-databind` | gestionada por BOM | varios |
| Mapeo/objeto | `org.reactivecommons.utils:object-mapper` / `object-mapper-api` | 0.1.0 | `jpa-repository`, `app-service` |
| TOTP | `com.eatthepath:java-otp` | 0.4.0 | `jpa-repository` |
| Codificación Base32 | `commons-codec:commons-codec` | 1.16.0 | `jpa-repository` |
| Secretos | `com.infisical:sdk` | 3.0.2 | `app-service` |
| Secretos (alterno) | `com.github.bancolombia:aws-secrets-manager-sync` | 4.4.33 | `app-service` |
| Boilerplate | `org.projectlombok:lombok` | 1.18.42 | todos (`compileOnly`/`annotationProcessor`) |
| Logging | `org.slf4j:slf4j-api` | gestionada por BOM | `service`, `brevo-sender` |
| Pruebas | `spring-boot-starter-test`, `spring-boot-starter-webmvc-test:4.0.2`, `spring-security-test` | — | ver `05-Pruebas.md` |
| Pruebas (mocks HTTP) | `com.squareup.okhttp3:mockwebserver` | 5.3.2 | `rest-consumer` |
| Pruebas (arquitectura) | `com.tngtech.archunit:archunit` | 1.4.1 | `app-service` |
| Calidad | JaCoCo, Pitest, plugin SonarQube | 0.8.14 / 1.19.0-rc.3 (plugin) / 1.22.0 (runtime) / 7.2.2.6593 | build raíz |

## 2. Estructura del código por capa

### 2.1 `domain/model` (`:model`) — núcleo de dominio

Contiene únicamente **POJOs inmutables o con builder** (Lombok `@Data`, `@Builder`), *value objects* (`Email`, `Name`, `UserId` en el paquete `vob`) y **13 interfaces de puerto** en `gateway/`. No tiene ninguna dependencia externa declarada (`build.gradle` vacío salvo los plugins comunes heredados de `main.gradle`). Ejemplo representativo — la entidad de dominio `User`:

```java
@Data
@Builder(toBuilder = true)
public class User {
    private UUID id;
    private String keycloakSub;
    private String fullName;
    private String email;
    private String status;
    private UUID organizationId;
    private Boolean mustChangePassword;
    private Instant createdAt;
    private Instant updatedAt;
}
```

Nótese la ausencia total de anotaciones JPA o Jackson: el modelo de dominio se mapea explícitamente a/desde entidades JPA (`UserEntity`) y DTOs REST (`UserResponse`) en las capas externas, evitando que un cambio de esquema de base de datos o de contrato HTTP fuerce cambios en el dominio.

### 2.2 `domain/usecase` (`:usecase`) — casos de uso

Cada caso de uso es una clase con una única responsabilidad, que depende solo de interfaces de `:model`. Ejemplo — `CreateUserUseCase` (sin Lombok, constructor explícito):

```java
public class CreateUserUseCase {
    private final UserManagementGateway userManagementGateway;
    public CreateUserUseCase(UserManagementGateway userManagementGateway) {
        this.userManagementGateway = userManagementGateway;
    }
    public CreateUserResult execute(CreateUserCommand command) {
        return userManagementGateway.createUser(command);
    }
}
```

Algunos casos de uso son puros *pass-through* al gateway (como el anterior), delegando toda la lógica de negocio al adaptador de servicio (`UserManagementService`); otros, como `LoginUseCase`, también delegan pero explicitan en Javadoc el contrato de excepciones esperado.

### 2.3 `infrastructure/driven-adapters` — adaptadores de salida

- **`service`** (`:service`): implementa los gateways que requieren **orquestación de negocio** entre varios adaptadores (Keycloak + BD + correo). `UserManagementService` es el ejemplo más completo: valida reglas de negocio (campo obligatorio, duplicidad de correo, existencia de organización), coordina la creación en Keycloak (`KeycloakAdminGateway`) y en BD (`UserPersistenceGateway`), genera contraseña temporal y dispara notificación de correo opcional.
- **`jpa-repository`** (`:jpa-repository`): adaptadores que implementan puertos de persistencia usando Spring Data JPA. Incluye `TotpAdapter`, que además de persistir usa criptografía real (`javax.crypto.KeyGenerator` con `HmacSHA1`, codificación Base32 con Apache Commons Codec, y la librería `java-otp` para generar/verificar códigos TOTP conforme a RFC 6238, con ventana de tolerancia de ±1 paso de 30 segundos).
- **`rest-consumer`** (`:rest-consumer`): clientes HTTP salientes construidos sobre `RestClient` de Spring (no `WebClient`). `KeycloakAuthAdapter` implementa el flujo OAuth2 *Resource Owner Password Credentials* contra el *token endpoint* de Keycloak, decodifica manualmente el payload del JWT (Base64URL) para extraer claims sin necesidad de validarlo (la validación de firma ocurre después, en `SecurityConfig`, cuando el mismo token se usa para llamadas subsecuentes), y traduce respuestas de error de Keycloak (`invalid_grant`, `"account is not enabled"`, `"account is not fully set up"`) a resultados de dominio tipados (`LoginResult.LoginFailed` / `LoginInactive`) mediante un *sealed-like* patrón de resultado.
- **`brevo-sender`** (`:brevo-sender`): adaptador de correo transaccional vía API de Brevo; implementa `EmailGateway` y se inyecta como dependencia **opcional** en `UserManagementService`.

### 2.4 `infrastructure/entry-points/api-rest` (`:api-rest`) — adaptadores de entrada

Controladores `@RestController` delgados: reciben DTO validado, lo mapean a comando/consulta de dominio con una clase `*Mapper` estática, invocan el caso de uso y mapean el resultado de vuelta a DTO de respuesta. Toda la lógica de negocio vive en `:usecase`/`:service`, nunca en el controlador. Incluye:

- `GlobalExceptionHandler` (`@RestControllerAdvice`) — traduce 10 tipos de excepción a respuestas HTTP consistentes.
- `TraceIdFilter`, `SecurityHeadersFilter`, `CorsConfig` — *cross-cutting concerns* de infraestructura HTTP.
- `InternalAuditApi` — único controlador protegido por API key en vez de JWT.

### 2.5 `infrastructure/helpers/common` (`:common`) — contrato compartido

Módulo transversal (no es puerto de dominio) usado tanto por `api-rest` como por los adaptadores de servicio: define el envoltorio de respuesta (`CorrectResponse`, `ErrorResponse`, `Meta`, `ErrorDetail`), el mapeador (`ApiResponseMapper`) y las 8 excepciones de negocio que atraviesan capas (lanzadas en `:service`/`:jpa-repository`/`:rest-consumer` y capturadas en `:api-rest`).

### 2.6 `applications/app-service` (`:app-service`) — módulo ejecutable

Punto de ensamblaje final. Contiene:

- `MainApplication` — `@SpringBootApplication` + `@ConfigurationPropertiesScan`, sin lógica adicional (excluido explícitamente de análisis Sonar: `sonar.exclusions = **/MainApplication.java`).
- `UseCaseConfig` / `UseCasesConfig` — *composition root*: instancian cada caso de uso vía `@Bean`, inyectando el gateway (interfaz) correspondiente; es el único punto del código donde el dominio "se entera" de qué implementación concreta usar, y lo hace por inyección de Spring, no por referencia directa.
- `SecurityConfig` — cadena de filtros de Spring Security, decodificador JWT (Nimbus), conversión de `realm_access.roles` a `GrantedAuthority`.
- `InternalApiKeyFilter` / `InternalApiProperties` — protección de `/internal/**`.
- `InfisicalConfig` — `BeanFactoryPostProcessor` que, si están presentes `INFISICAL_SITE_URL`, `INFISICAL_PROJECT_ID` e `INFISICAL_ENVIRONMENT` (más credenciales de autenticación), recupera secretos de Infisical **antes** de que se resuelvan los placeholders `${...}` del resto de la configuración, inyectándolos como `PropertySource` de máxima prioridad (`addFirst`). Si Infisical no está configurado, el post-processor no hace nada y la aplicación usa las variables de entorno/valores por defecto normales — diseño *fail-open* hacia configuración local.
- `DBCredentialConfig` / `DBCredential` — parseo de la variable `DB_CREDENTIAL` (JSON) hacia las propiedades de `DataSource` de Spring.
- `KeycloakRestClientConfig` / `RestClientConfig` — *beans* `RestClient` nombrados (`@Qualifier("keycloakRestClient")`) para separar el cliente HTTP hacia Keycloak del cliente genérico hacia otros microservicios.
- `UserQueryGatewayAdapter` (paquete `userquery`) — implementación de `UserQueryGateway` ubicada en el módulo ejecutable en lugar de en `jpa-repository`, probablemente porque combina consultas de `UserJpaAdapter` con lógica de mapeo de roles que requiere acceso a beans ensamblados en este nivel.

## 3. Patrones y estándares aplicados

| Patrón | Dónde se aplica |
|---|---|
| **Puertos y adaptadores (Hexagonal)** | Todo el proyecto; interfaces en `:model/gateway`, implementaciones en `driven-adapters/*` |
| **Inyección de dependencias por constructor** | Todas las clases de infraestructura (`@RequiredArgsConstructor` de Lombok o constructor explícito) |
| **Composition Root explícito** | `UseCaseConfig`/`UseCasesConfig` en `:app-service`; el dominio nunca usa `@Autowired` ni `@Component` |
| **DTO ↔ Dominio con mapeadores estáticos dedicados** | `AuthApiMapper`, `UsersApiMapper`, `UserInfoMapper` |
| **Result/Sealed pattern para resultados de negocio** | `LoginResult` (`LoginSuccess`/`LoginFailed`/`LoginInactive`) — evita usar excepciones para flujo de control esperado dentro del adaptador, y las traduce a excepciones solo en la capa de orquestación (`LoginService`) |
| **Excepciones de dominio tipadas y centralizadas** | `:common/exception` + `GlobalExceptionHandler` (patrón *Controller Advice*) |
| **Filtros Servlet para cross-cutting concerns de seguridad** | `InternalApiKeyFilter`, `SecurityHeadersFilter`, `TraceIdFilter` (todos `OncePerRequestFilter` o equivalentes) |
| **Dependencia opcional vía `@Autowired(required = false)`** | `UserManagementService.emailGateway` — degrada con gracia si Brevo no está configurado |
| **BeanFactoryPostProcessor para inyección temprana de configuración** | `InfisicalConfig` — patrón avanzado de Spring para resolver placeholders antes del ciclo normal de beans |
| **Multi-módulo Gradle como *build-time enforcement*** | `settings.gradle` + reglas de dependencia entre `build.gradle` de cada módulo |
| **Value Objects** | `Email`, `Name`, `UserId` en `domain/model/.../vob` |

## 4. Principales funcionalidades desarrolladas

1. **Autenticación ROPC contra Keycloak** con traducción de errores del IdP a resultados de dominio y auditoría incondicional (`LoginUseCase` → `LoginService` → `KeycloakAuthAdapter`).
2. **Flujo de primer acceso con contraseña temporal** y bloqueo de login hasta cambiar la contraseña (`must_change_password`).
3. **2FA TOTP completo**: generación de secreto (`TotpAdapter.generateSecret`, HmacSHA1/Base32), construcción de URL `otpauth://` para QR (`TotpSetupUseCase`), verificación con tolerancia de reloj y habilitación persistente (`iam.user_totp.enabled_at`).
4. **CRUD administrativo de usuarios** con sincronización bidireccional Keycloak↔BD local (creación, actualización de nombre/correo/roles, activación/inactivación, reset de contraseña).
5. **Integración cross-microservicio de validación de organización** (`OrganizationGatewayAdapter` → `GET /organizations/{id}` en `ms_org`).
6. **Bitácora de auditoría de doble propósito**: registro interno de intentos de login y API pública interna (`POST /internal/audit/events`) para que otros microservicios registren sus propios eventos de negocio en la misma tabla.
7. **Catálogo de roles con etiquetas en español** para consumo directo por frontends, sin necesidad de tabla de traducción propia en el cliente.
8. **Notificación transaccional por correo** (contraseña temporal / reset) vía Brevo, desacoplada mediante gateway opcional.
9. **Carga de secretos en tiempo de arranque desde Infisical**, con *fallback* transparente a configuración local/H2 cuando no está disponible (facilita desarrollo local sin credenciales de producción).
