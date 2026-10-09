# ms_catalog — Planificación

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_catalog` |
| Sistema | MSPI (Modelo de Seguridad y Privacidad de la Información — ISO/IEC 27001) |
| Fecha del documento | 2026-08-19 |
| Alcance | Fase de planificación del microservicio `ms_catalog` dentro de la arquitectura de microservicios MSPI |

---

## 1. Contexto del sistema MSPI

MSPI es un sistema de gestión de seguridad de la información construido como un conjunto de microservicios Java/Spring independientes que colaboran vía HTTP/REST y comparten un modelo de datos lógico particionado por esquema de base de datos (uno por microservicio: `iam`, `org`, `catalog`, `evidence`, `assessment`, `audit`, …). El repositorio contenedor `MSPI_NVA_CO_MR_BACK` agrupa cada microservicio como carpeta independiente, y `docker-config/` centraliza la orquestación local (Docker Compose, Keycloak).

`ms_catalog` es el microservicio de **catálogos paramétricos del instrumento MSPI**. Es un servicio fundacional de solo lectura: define y expone la versión publicada del instrumento de evaluación (plantilla, árbol de controles ISO 27001 Anexo A, ciclo PHVA, requisitos de madurez, mapeo NIST CSF y escala de calificación 0–100/N.A.) que consumen `ms_assessment` (creación y resolución de evaluaciones), `ms_reporting` (generación de reportes PDF/Excel) y el frontend.

## 2. Alcance del microservicio

`ms_catalog` cubre exclusivamente la responsabilidad de negocio de **definición y publicación del instrumento MSPI como catálogo paramétrico de solo lectura**. Concretamente, según el código (`CatalogApi.java`, 17 endpoints `GET`) y `docs/openapi.yaml`:

- **Tipos de orden territorial** (`entity-order-types`): Nacional, Territorial A/B/C, con el porcentaje de avance PHVA esperado por tipo.
- **Versión de plantilla activa** (`template-versions/active`): resuelve la versión del instrumento en estado `PUBLISHED` vigente, base para el resto de consultas cuando no se especifica `templateVersionId`.
- **Inventario documental de levantamiento** (`lifting-document-items`): 43 ítems por bloques temáticos.
- **Cargos responsables** (`steward-roles`) y **áreas predefinidas** (`assessment-area-presets`) del instrumento (Módulo 2 / HU-AR-01).
- **Catálogo de controles ISO 27001 Anexo A**: 14 dominios ISO (`iso-domains`), árbol jerárquico completo (`control-catalog-tree`), controles hoja calificables filtrables por rama `ADMIN`/`TECH` (`control-catalog-leaves`), y reglas de validación por control hoja (`control-rules`: evidencia/brecha/recomendación obligatorias).
- **Escala de evaluación publicada** (`scales/published`): niveles 0–100 y bandas de semáforo.
- **Mapeo de controles a NIST CSF** (`nist-mappings`).
- **Ciclo PHVA**: catálogo versionado (`phva-items`) y pesos/topes Plan/Do/Check/Act (`phva-config`). **template_version v2**: 7 cláusulas ISO `C.4`–`C.10` (MANUAL) con pesos/caps **56/16/14/14**; v1 conserva ~17 ítems `P.1`…`M.2` con 40/20/20/20.
- **Requisitos de madurez**: ~50 ítems Rn (`maturity-requirements`) con umbrales por nivel 1–5, y configuración de umbrales críticos (`maturity-config`).
- **Hoja Ciber (NIST CSF)**: filas `nist-ciber-items` y metas (`nist-config`). **v2 = CSF 2.0**: 6 funciones (**GV/Gobernar**, ID, PR, DE, RS, RC) y 22 categorías MANUAL; v1 = enfoque CSF 1.1 (5 funciones + filas heredadas).

Todo el catálogo es **inmutable en tiempo de ejecución** desde la perspectiva del microservicio: `ms_catalog` no expone ningún endpoint de escritura (no hay `POST`/`PUT`/`PATCH`/`DELETE` en `CatalogApi`); la administración del contenido del instrumento se realiza fuera de este microservicio (scripts SQL versionados, `schema.sql` + `data.sql`/`nist_ciber_data.sql`/`maturity_data.sql`).

Quedan **fuera de alcance** de `ms_catalog`: la ejecución de evaluaciones y el almacenamiento de respuestas de entidades evaluadas (los snapshots del instrumento al momento de evaluar viven en `ms_assessment`), la gestión de usuarios/roles (`ms_iam`), la gestión de organizaciones (`ms_org`), la gestión de evidencias (`ms_evidence`) y la generación de reportes (`ms_reporting`).

## 3. Objetivos

1. Mantener un único punto de verdad para la **definición del instrumento MSPI** (plantilla publicada, escala, árbol de controles, requisitos PHVA/madurez/NIST) desacoplado de los microservicios que ejecutan o reportan evaluaciones.
2. Servir el catálogo activo (versión `PUBLISHED`) de forma consistente y filtrable por `templateVersionId`, con resolución automática a la plantilla activa cuando el consumidor no la especifica.
3. Proveer datos paramétricos suficientes para que `ms_assessment` pueda materializar snapshots de evaluación (áreas, controles, cargos responsables, requisitos) sin duplicar lógica de negocio de catálogo.
4. Servir la escala publicada y las reglas por control para que `ms_reporting` construya reportes (PDF/Excel, hoja "Escala") consistentes con el instrumento vigente.
5. Mantener el microservicio desacoplado de infraestructura mediante arquitectura hexagonal: el dominio (`domain/model`, `domain/usecase`) no depende de Spring ni de JPA.
6. Proteger el catálogo con autenticación JWT (Keycloak), delegando la gestión de identidad a `ms_iam`.

## 4. Requerimientos iniciales

A partir del código y la documentación (`README.md`, `docs/openapi.yaml`, `schema.sql`) se identifican los siguientes requerimientos que dieron forma al microservicio:

- **RI-1** — El servicio es **de solo lectura**: los 17 endpoints de `CatalogApi` son exclusivamente `GET`; no existe capa de escritura HTTP.
- **RI-2** — Debe resolver automáticamente la **plantilla activa** (`status = PUBLISHED`, la más reciente por `published_at`) cuando el consumidor no indica `templateVersionId` explícito, en la mayoría de los 17 casos de uso (todos salvo `GetActiveTemplateVersionUseCase`, `GetEntityOrderTypesUseCase`, `GetStewardRolesUseCase`, `GetIsoDomainsUseCase` y `GetAssessmentAreaPresetsUseCase`, que no dependen de plantilla).
- **RI-3** — Sin plantilla publicada, `GET /catalog/template-versions/active` debe responder `404`.
- **RI-4** — Los controles hoja calificables (`control-catalog-leaves`) deben filtrarse por rama `ADMIN`/`TECH` mediante el parámetro opcional `controlType`.
- **RI-5** — El microservicio **no ejecuta DDL/DML al arranque** (`spring.sql.init.mode: never`, `hibernate.ddl-auto: none`); el esquema y los datos paramétricos se gestionan por scripts SQL versionados (`schema.sql`, `data.sql`, `nist_ciber_data.sql`, `maturity_data.sql`) aplicados fuera del ciclo de vida de Spring Boot.
- **RI-6** — Los pesos, topes y umbrales de configuración (PHVA, madurez, NIST) se almacenan como columnas `JSONB` en `catalog.template_version` (`phva_weights`, `phva_caps`, `maturity_crit_thresholds`, `nist_function_targets`) y deben tener valores por defecto de repliegue (*fallback*) cuando la plantilla no define un valor explícito.
- **RI-7** — El servicio debe exponer *health checks* (`/actuator/health`, `/actuator/info`) para condicionar el arranque de microservicios dependientes en Docker Compose.
- **RI-8** — Todas las rutas `/catalog/**` requieren autenticación (JWT Bearer emitido por Keycloak, realm `iam`), salvo `/actuator/health`, `/actuator/info` y `/error`.

## 5. Stack tecnológico (versiones reales verificadas en el código)

| Componente | Versión / detalle | Evidencia |
|---|---|---|
| Lenguaje | Java 21 (toolchain) | `main.gradle`: `JavaLanguageVersion.of(21)` |
| Framework | Spring Boot **4.0.2** | `build.gradle`: `springBootVersion = '4.0.2'` |
| Gestor de build | Gradle **9.3.0** (wrapper) | `main.gradle`: `tasks.named('wrapper') { gradleVersion = '9.3.0' }` |
| Modelo web | Spring MVC (servlet, no reactivo) | `spring-boot-starter-webmvc` en `api-rest/build.gradle` |
| Seguridad | Spring Security + OAuth2 Resource Server (JWT) | `spring-security-oauth2-resource-server`, `spring-security-oauth2-jose` en `app-service` y `api-rest` |
| Persistencia | Spring Data JPA + PostgreSQL | `spring-boot-starter-data-jpa` en `jpa-repository/build.gradle`, `runtimeOnly 'org.postgresql:postgresql'` |
| Base de datos | PostgreSQL, schema `catalog` (sin H2 declarado en ningún módulo) | `application.yaml`: `hibernate.databasePlatform: PostgreSQLDialect`, `schema.sql` |
| Gestión de secretos | Infisical SDK 3.0.2 | `com.infisical:sdk:3.0.2` en `app-service/build.gradle`, `InfisicalConfig.java` |
| Serialización | Jackson (`jackson-databind`) | `app-service/build.gradle`, uso en `DBCredentialConfig` |
| Lombok | 1.18.42 | `build.gradle` raíz |
| Pruebas | JUnit 5 (`useJUnitPlatform()`), Mockito (vía `spring-boot-starter-test`), Spring Security Test | ver detalle en `05-Pruebas.md` |
| Cobertura / calidad | JaCoCo 0.8.14, Pitest (mutation testing) 1.19.0-rc.3 / 1.22.0, SonarQube plugin 7.2.2.6593 | `build.gradle`, `main.gradle` |
| Contenedor | `eclipse-temurin:21-jdk-alpine` (build) → `eclipse-temurin:21-jre-alpine` (runtime) | `deployment/Dockerfile` |
| CI/CD | Bitbucket Pipelines, despliegue a Railway | `bitbucket-pipelines.yml` |

## 6. Estructura del proyecto (multi-módulo Gradle)

`settings.gradle` define 6 módulos siguiendo arquitectura hexagonal (Clean Architecture aplicada manualmente por convención de carpetas, sin plugin de generación de estructura):

```
MsCatalog (rootProject)
├── domain/model        → :model        (entidades/VOs de catálogo, puerto CatalogPersistenceGateway — sin dependencias de framework)
├── domain/usecase       → :usecase      (17 casos de uso GET — solo depende de :model y :common)
├── infrastructure/helpers/common → :common (DTOs de respuesta CorrectResponse/ErrorResponse, excepciones de dominio compartidas)
├── infrastructure/driven-adapters/jpa-repository → :jpa-repository (CatalogJpaAdapter, entidades JPA, repositorios Spring Data)
├── infrastructure/entry-points/api-rest → :api-rest (CatalogApi, seguridad JWT, DTOs de respuesta, GlobalExceptionHandler)
└── applications/app-service → :app-service (módulo ejecutable Spring Boot, MainApplication, wiring de casos de uso, Infisical, DB credential)
```

El módulo `:common` es compartido con el resto de microservicios MSPI (se observan en él excepciones como `IamServiceException` y `UserAlreadyExistsException` que no tienen ningún caso de uso real en `ms_catalog` — evidencia de que el módulo `common` se replicó desde `ms_iam`/`ms_org` como plantilla base, ver `04-Desarrollo.md`).

## 7. Recursos y planificación del desarrollo

No se encontró en el repositorio de `ms_catalog` un archivo `ROADMAP.md`, `CHANGELOG.md` ni un plan de iteraciones específico del microservicio. La planificación general del proyecto de grado se documenta a nivel de todo el sistema MSPI en:

- `docs/proyecto/PLAN_TRABAJO_MSPI_v2.md` (repositorio raíz) — plan de trabajo global del proyecto.
- `docs/proyecto/Historias_Usuario_MSPI_v2.md` — historias de usuario del sistema completo. Varias HU están directamente evidenciadas en comentarios del código de `ms_catalog`: `HU-CFG-02`, `HU-CFG-05` (catálogo general), `HU-AR-01` (áreas/cargos), `HU-DIAG-01` (dominios ISO), `HU-ADM-01..04` (controles/árbol/reglas), `HU-PHVA-01..05`, `HU-MAD-01..05`, `HU-CIB-01..03` (NIST/Ciber).
- `ms_catalog/docs/MVP-MSPI-CONTRATOS-Y-MER.md` — documento de contratos entre microservicios y cambios al MER, centrado en el contrato `ms_iam`↔`ms_org`; no define contratos específicos de `ms_catalog`, pero confirma que la arquitectura hexagonal y el patrón `CorrectResponse`/`ErrorResponse` se replicaron consistentemente desde `ms_iam` a los demás microservicios del sistema.
- `docs/linea_base_seguridad_ISO27001.md` (repositorio raíz) — línea base de controles de seguridad ISO/IEC 27001 que fundamenta el propio contenido del catálogo que expone este microservicio (el árbol de controles, dominios y reglas persistidos en `catalog.control_catalog_node`/`catalog.iso_domain` reflejan directamente el Anexo A de ISO 27001).
- `docker-config/docs/PLAN_TRABAJO_MSPI_v2.md` e `INSTRUCCIONES-EQUIPO.md` — documentación operativa del equipo para todo el sistema.

Dado que no existe evidencia de un cronograma o backlog propio de `ms_catalog`, este documento declara explícitamente esa ausencia en lugar de inventar fechas o hitos. La densidad de datos seedeados (`data.sql` 824 líneas, `maturity_data.sql` 328 líneas, `nist_ciber_data.sql` 58 líneas) sugiere que gran parte del esfuerzo de "desarrollo" de este microservicio consistió en la **transcripción del instrumento MSPI real (hoja de cálculo/Excel de línea base ISO 27001) a datos relacionales**, más que en lógica de negocio compleja.

## 8. Actores interesados (stakeholders) inferidos del dominio

| Actor | Interés en `ms_catalog` |
|---|---|
| Frontend MSPI | Consumidor directo de los 17 endpoints para renderizar formularios de evaluación, árbol de controles y panel de administración del instrumento |
| `ms_assessment` | Consumidor principal: resuelve `templateVersionId` activo, controles hoja, áreas, cargos y requisitos PHVA/madurez/NIST al crear una evaluación y materializar su snapshot |
| `ms_reporting` | Consume la escala publicada (`scales/published`) para renderizar la hoja "Escala" en reportes PDF/Excel |
| `ms_iam` | Emisor de JWT (Keycloak) consumido por `SecurityConfig`; sin llamadas directas entre ambos servicios |
| Equipo DevOps / DBA | Responsables de aplicar `schema.sql` y los seeds (`data.sql`, `nist_ciber_data.sql`, `maturity_data.sql`), dado que el microservicio no ejecuta DDL/DML |
| Administrador del instrumento (rol de negocio, sin API de escritura evidenciada en este MS) | Interesado en el contenido del catálogo (controles, PHVA, madurez, NIST); su gestión no está implementada como API en `ms_catalog` |
