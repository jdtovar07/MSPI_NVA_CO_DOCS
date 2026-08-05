# ms_org — Planificación

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_org` |
| Sistema | MSPI (Modelo de Seguridad y Privacidad de la Información — ISO/IEC 27001) |
| Fecha del documento | 2026-08-19 |
| Alcance | Fase de planificación del microservicio `ms_org` dentro de la arquitectura de microservicios MSPI |

---

## 1. Contexto del sistema MSPI

MSPI es un sistema de gestión de seguridad de la información construido como un conjunto de microservicios Java/Spring independientes que colaboran vía HTTP/REST y comparten un modelo de datos lógico particionado por esquema de base de datos (uno por microservicio: `iam`, `org`, `catalog`, `evidence`, `assessment`, `audit`, …). El repositorio contenedor `MSPI_NVA_CO_MR_BACK` agrupa cada microservicio como carpeta independiente, y `docker-config/` centraliza la orquestación local con Docker Compose, incluyendo Keycloak como *Identity Provider* y PostgreSQL como base de datos compartida (particionada por esquema).

`ms_org` es el microservicio de **gestión organizacional** del sistema: administra las entidades evaluadas (organizaciones) que son objeto de las evaluaciones de seguridad del sistema MSPI, y expone además un catálogo geográfico público (países, departamentos/estados, ciudades) consumido por los formularios de alta de organización en el frontend. A diferencia de `ms_iam` (servicio fundacional del que todo depende para autenticación), `ms_org` es un servicio de **dominio de negocio**: no emite tokens, pero es consultado tanto por `ms_iam` (al crear un usuario con rol `Lector`, valida que la organización exista) como, previsiblemente, por `ms_assessment`, `ms_evidence` y `ms_reporting`, que referencian `organization_id` sin clave foránea cruzada de esquema (según `docs/MVP-MSPI-CONTRATOS-Y-MER.md`).

## 2. Alcance del microservicio

`ms_org` cubre exclusivamente la responsabilidad de negocio de **alta, consulta y actualización de organizaciones**, y de **catálogo geográfico de apoyo**. Concretamente:

- **CRUD de organizaciones**: creación (`POST /organizations`), listado paginado con filtros (`GET /organizations`), consulta por id (`GET /organizations/{id}`) y actualización completa (`PUT /organizations/{id}`), todo restringido al rol `AdminSistema`.
- **Consulta propia** (`GET /organizations/my-organization`): un usuario con rol `Lector` puede consultar los datos de su propia organización, resolviendo el `organizationId` desde el header `X-Organization-Id` o desde el claim `organization_id` del JWT emitido por Keycloak.
- **Orquestación de aprovisionamiento de usuario**: al crear una organización, `ms_org` persiste el contacto principal (`org.organization_contact`) y llama a `ms_iam` (`POST /users`) para crear el usuario `Lector` asociado; si esa llamada falla, revierte (rollback manual) la organización y el contacto ya persistidos.
- **Sincronización de contacto en actualización**: si al actualizar una organización cambia el correo del contacto principal, desactiva el usuario `Lector` anterior en `ms_iam` (`POST /users/disable-by-email`) y provisiona uno nuevo con el correo actualizado.
- **Catálogo geográfico público** (`/location/**`, sin autenticación): países, departamentos/estados y ciudades, consumidos en tiempo real desde la API externa **Country State City** (`countrystatecity.in`).

Quedan **fuera de alcance** de `ms_org` (y son responsabilidad de otros microservicios del sistema): identidad y autenticación (`ms_iam`), catálogos de instrumentos/controles (`ms_catalog`), evidencias (`ms_evidence`), evaluaciones (`ms_assessment`) y reportería (`ms_reporting`). `ms_org` no gestiona roles, contraseñas ni auditoría transversal; su única tabla de auditoría/trazabilidad es implícita vía `X-Trace-Id` en logs, sin tabla de bitácora propia (a diferencia de `ms_iam`, que sí mantiene `iam.audit_log`).

## 3. Objetivos

1. Proveer un registro único y consistente de las organizaciones evaluadas dentro de MSPI, con unicidad garantizada por `(name, identifier)` a nivel de base de datos.
2. Desacoplar la gestión organizacional de la gestión de identidad, delegando en `ms_iam` la creación real del usuario `Lector`, pero coordinando ambos procesos de forma transaccional-compensatoria (rollback si `ms_iam` falla).
3. Ofrecer a los usuarios `Lector` una vía de autoservicio para consultar los datos de su propia organización sin necesidad de conocer su `organizationId` explícitamente (resolución vía JWT).
4. Reducir fricción en los formularios de alta de organización proveyendo un catálogo geográfico público y actualizado, sin necesidad de que el frontend mantenga listas estáticas de países/departamentos/ciudades.
5. Mantener el microservicio desacoplado de infraestructura mediante arquitectura hexagonal, replicando el patrón ya validado en `ms_iam` (dominio sin dependencias de Spring/JPA/HTTP).

## 4. Requerimientos iniciales

A partir del código, el `README.md` y `docs/MVP-MSPI-CONTRATOS-Y-MER.md` se identifican los siguientes requerimientos que dieron forma al microservicio:

- **RI-1** — Toda organización debe tener nombre e identificador (NIT/RFC u otro) únicos como par; el sistema debe rechazar duplicados tanto en creación como en actualización (`BusinessRulesOnFieldsException` → HTTP 400).
- **RI-2** — La creación de una organización debe provisionar automáticamente un usuario `Lector` en `ms_iam` usando el correo de contacto (`organizationEmail`), obligatorio en el `POST`.
- **RI-3** — Si la creación del usuario `Lector` en `ms_iam` falla (correo duplicado, servicio caído), la organización y el contacto ya persistidos deben revertirse (no debe quedar una organización "huérfana" sin usuario asociado).
- **RI-4** — El usuario `Lector` debe poder autoconsultar su organización sin necesidad de conocer su UUID, resolviéndolo desde el JWT (claim `organization_id`) o desde un header explícito (`X-Organization-Id`) como mecanismo alterno para el BFF/frontend.
- **RI-5** — El catálogo de ubicación (países/estados/ciudades) debe ser público (sin JWT), dado que se usa en el formulario de registro antes de que exista sesión autenticada de `AdminSistema` en algunos flujos de frontend.
- **RI-6** — El microservicio **no debe** ejecutar DDL automáticamente (`spring.sql.init.mode: never`, `hibernate.ddl-auto: none`); el esquema `org` se gestiona por scripts SQL versionados (`schema.sql` es solo referencia de desarrollo).
- **RI-7** — El servicio debe exponer *health checks* (`/actuator/health`, `/actuator/info`) para que Docker Compose condicione el arranque de servicios dependientes.
- **RI-8** — A diferencia de `ms_iam`, `ms_org` **no tiene fallback a H2**: `DBCredentialConfig` lanza `IllegalStateException` si `DB_CREDENTIAL` no está presente, por lo que el servicio requiere PostgreSQL real incluso en desarrollo local.

## 5. Stack tecnológico (versiones reales verificadas en el código)

| Componente | Versión / detalle | Evidencia |
|---|---|---|
| Lenguaje | Java 21 (toolchain) | `main.gradle`: `JavaLanguageVersion.of(21)` |
| Framework | Spring Boot **4.0.2** | `build.gradle`: `springBootVersion = '4.0.2'` |
| Gestor de build | Gradle **9.3.0** (wrapper) | `main.gradle`: `tasks.named('wrapper') { gradleVersion = '9.3.0' }` |
| Modelo web | Spring MVC (servlet, no reactivo) | dependencia `spring-boot-starter-webmvc` en `api-rest/build.gradle` |
| Seguridad | Spring Security + OAuth2 Resource Server (JWT) | `spring-security-oauth2-resource-server`, `spring-security-oauth2-jose` en `api-rest` y `app-service` |
| Persistencia | Spring Data JPA + Hibernate + HikariCP | `spring-boot-starter-data-jpa` en `jpa-repository/build.gradle`; `JpaConfig` configura `HikariDataSource` manualmente |
| Base de datos | PostgreSQL (única; sin fallback H2) | `runtimeOnly 'org.postgresql:postgresql'`; `DBCredentialConfig` exige `DB_CREDENTIAL` obligatorio |
| Cliente HTTP saliente | `RestClient` (Spring) hacia `ms_iam` y Country State City API | `IamRestClientConfig`, `CountryStateCityClientConfig` |
| Gestión de secretos | Infisical SDK 3.0.2 | `com.infisical:sdk:3.0.2` en `app-service/build.gradle` |
| Validación | Jakarta Bean Validation (`@NotBlank`) | `spring-boot-starter-validation`, `OrganizationRequest` |
| Observabilidad | Spring Boot Actuator (`/actuator/health`, `/actuator/info`) | `spring-boot-starter-actuator` en `api-rest/build.gradle` |
| Serialización | Jackson (`com.fasterxml.jackson.core:jackson-databind`) | `IamGatewayAdapter`, `JacksonConfig` |
| Lombok | 1.18.42 | `build.gradle` raíz |
| Pruebas | JUnit 5 (`useJUnitPlatform()`), Mockito (vía `spring-boot-starter-test`), Spring Security Test | ver detalle en `05-Pruebas.md` |
| Cobertura / calidad | JaCoCo 0.8.14, Pitest (mutation testing) 1.19.0-rc.3 (plugin) / 1.22.0 (motor), SonarQube plugin 7.2.2.6593 | `build.gradle`, `main.gradle` (idéntico a `ms_iam`) |
| Contenedor | `eclipse-temurin:21-jdk-alpine` (build) → `eclipse-temurin:21-jre-alpine` (runtime) | `deployment/Dockerfile` |
| CI/CD | Bitbucket Pipelines, despliegue a Railway | `bitbucket-pipelines.yml` |

## 6. Estructura del proyecto (multi-módulo Gradle)

`settings.gradle` define **6 módulos** (menos que `ms_iam`, que tiene 8; `ms_org` no tiene módulos `rest-consumer` ni `service` separados — los adaptadores REST salientes viven directamente en `applications/app-service`):

```
MsOrg (rootProject)
├── domain/model                                  → :model         (Organization, ubicaciones, puertos/gateways)
├── domain/usecase                                 → :usecase       (8 casos de uso — solo depende de :model)
├── infrastructure/helpers/common                  → :common        (CorrectResponse/ErrorResponse, excepciones de dominio)
├── infrastructure/driven-adapters/jpa-repository   → :jpa-repository (adaptador de persistencia JPA/PostgreSQL)
├── infrastructure/entry-points/api-rest            → :api-rest      (OrganizationApi, LocationApi, seguridad, DTOs)
└── applications/app-service                        → :app-service   (MainApplication, wiring, adaptadores REST salientes hacia ms_iam y Country State City, Infisical, JPA config)
```

**Particularidad de diseño**: a diferencia de `ms_iam`, que separa `rest-consumer` (cliente Keycloak) como módulo de infraestructura independiente, `ms_org` implementa sus dos adaptadores REST salientes (`IamGatewayAdapter` hacia `ms_iam`, `LocationCatalogAdapter` hacia Country State City) **directamente dentro de `applications/app-service`** (paquetes `co.com.mspi.iam` y `co.com.mspi.location`), junto con `CreateOrganizationGatewayAdapter`. Esto concentra más lógica de infraestructura en el módulo ejecutable de lo que sugeriría una separación hexagonal estricta; se documenta como observación de diseño en `03-Diseno.md`.

## 7. Recursos y planificación del desarrollo

No se encontró en el repositorio de `ms_org` un archivo `ROADMAP.md`, `CHANGELOG.md` ni un plan de iteraciones específico del microservicio. La planificación general del proyecto de grado se documenta a nivel de todo el sistema MSPI en los documentos compartidos del repositorio contenedor (`docs/proyecto/PLAN_TRABAJO_MSPI_v2.md`, `docs/proyecto/Historias_Usuario_MSPI_v2.md`, `docs/proyecto/DB-MER.txt`), consistente con lo ya observado al documentar `ms_iam`.

El documento `docs/MVP-MSPI-CONTRATOS-Y-MER.md` (dentro del propio `ms_org`) sí funciona como una suerte de acta de diseño puntual: registra que la arquitectura de `ms_org` **replica deliberadamente** la de `ms_iam` ("Se replicó la arquitectura de ms_iam en ms_org"), define el contrato mínimo entre ambos servicios y documenta las historias de usuario cubiertas (`HU-MVP-001` a `HU-MVP-003` y `HU-MVP-008`). Dado que no existe evidencia de un cronograma o backlog propio adicional, este documento declara explícitamente esa ausencia en lugar de inventar fechas o hitos.

El historial de control de versiones del repositorio contenedor (`git log`) muestra únicamente 3 commits raíz (creación inicial, migración al monorepo, incorporación de `docker-config`), lo que confirma que no hay historial de iteraciones incrementales versionado a nivel de `ms_org` individualmente.

## 8. Actores interesados (stakeholders) inferidos del dominio

| Actor | Interés en `ms_org` |
|---|---|
| `AdminSistema` (administrador del sistema MSPI) | Consumidor directo de `POST/GET/PUT /organizations/**`: da de alta, consulta y actualiza organizaciones evaluadas |
| Usuario `Lector` (representante de la organización evaluada) | Consumidor de `GET /organizations/my-organization`; su cuenta es aprovisionada automáticamente por `ms_org` al crear la organización |
| `ms_iam` | Proveedor de `POST /users` y `POST /users/disable-by-email` (consumidos por `ms_org`); a su vez consumidor de `GET /organizations/{id}` para validar organizaciones al crear usuarios `Lector` |
| `ms_assessment` / `ms_evidence` / `ms_reporting` | Consumidores implícitos de `organization_id` como clave de referencia (sin FK cross-schema), según `docs/MVP-MSPI-CONTRATOS-Y-MER.md` |
| Country State City API (`countrystatecity.in`) | Proveedor externo del catálogo geográfico consumido por `LocationCatalogAdapter` |
| Frontend (`mf_org` y otros microfrontends) | Consumidor de `/organizations/**` (formularios de gestión) y `/location/**` (selects dependientes país→departamento→ciudad) |
| Equipo DevOps / DBA | Responsable de aplicar el DDL del esquema `org` (`docs/MVP-MSPI-CONTRATOS-Y-MER.md` §6.1), dado que el microservicio no ejecuta DDL |
| Keycloak (IdP) | Emisor de los JWT validados por `SecurityConfig`; `ms_org` actúa únicamente como *Resource Server*, no como cliente administrativo |
