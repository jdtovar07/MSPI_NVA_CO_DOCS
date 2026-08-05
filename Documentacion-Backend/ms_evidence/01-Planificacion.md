# ms_evidence — Planificación

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_evidence` |
| Sistema | MSPI (Modelo de Seguridad y Privacidad de la Información — ISO/IEC 27001) |
| Fecha del documento | 2026-08-19 |
| Alcance | Fase de planificación del microservicio `ms_evidence` dentro de la arquitectura de microservicios MSPI |

---

## 1. Contexto del sistema MSPI

MSPI es un sistema de gestión de seguridad de la información construido como un conjunto de microservicios Java/Spring independientes que colaboran vía HTTP/REST y comparten un modelo de datos lógico particionado por esquema de base de datos (uno por microservicio: `iam`, `org`, `catalog`, `evidence`, `assessment`, `audit`, …). El repositorio contenedor `MSPI_NVA_CO_MR_BACK` agrupa cada microservicio como carpeta independiente, y `docker-config/` centraliza la orquestación local con Docker Compose (`docker-config/docker/docker-compose.apps.yml`).

`ms_evidence` implementa el **Módulo 1** del dominio funcional MSPI: gestión del **contexto organizacional de la evaluación**, el **alcance de procesos**, el **levantamiento (inventario) de evidencia documental** y los **archivos de soporte** que sustentan una evaluación de seguridad de la información (evidencias para auditoría ISO 27001). Es consumido tanto por el frontend (usuarios finales autenticados con JWT) como server-to-server por `ms_assessment` (inicialización/clonación del levantamiento, consulta de contexto y de archivos) y `ms_reporting` (subida y descarga de salidas de reporte PDF/XLSX), mediante un canal interno independiente protegido con `X-Internal-Api-Key`.

## 2. Alcance del microservicio

`ms_evidence` cubre exclusivamente la responsabilidad de negocio de **evidencias documentales y contexto de evaluación** del dominio MSPI. Concretamente:

- **Contexto de evaluación** (`assessment_context`): misión, análisis de contexto, mapa de procesos, organigrama y auto-percepción (interés/preocupación, madurez, componente PHVA) de la organización evaluada.
- **Alcance de procesos** (`process_scope_metric`): total de procesos, procesos en alcance y cobertura calculada (`en_alcance / total`), con detección de inconsistencia (`in_scope_exceeds_total`).
- **Levantamiento documental** (`lifting_document_delivery`): estado de entrega (`DELIVERED`, `NOT_DELIVERED`, `PARTIAL`) por ítem del catálogo documental de una evaluación, con soporte de inicialización, clonación entre evaluaciones y actualización individual.
- **Archivos de evidencia** (`evidence_file`): subida (multipart), listado filtrado, descarga de binario y borrado lógico de archivos asociados a contexto (`CONTEXT`), documentos de levantamiento (`LIFTING_DOC`) o salidas de reporte (`REPORT_OUTPUT`), con validación de tipo MIME, tamaño máximo y cálculo de hash SHA-256 de integridad.
- **API interna server-to-server** (`/internal/**`), autenticada con `X-Internal-Api-Key` (sin JWT de usuario), consumida por `ms_assessment` (inicializar/clonar levantamiento, listar evidencias, consultar contexto) y por `ms_reporting` (subir salidas de reporte generadas y descargar archivos internamente).

Quedan **fuera de alcance** de `ms_evidence` (responsabilidad de otros microservicios del sistema): autenticación e identidad (`ms_iam`), gestión de organizaciones (`ms_org`), catálogos de instrumentos/controles y catálogo documental (`ms_catalog`), lógica de evaluación/diagnóstico (`ms_assessment`), generación de reportes (`ms_reporting`) y consolidación de auditoría transversal (`ms_audit`). El campo `assessment_id` se almacena en `ms_evidence` **sin llave foránea cross-schema** hacia `ms_assessment` (los esquemas de PostgreSQL son independientes por microservicio).

## 3. Objetivos

1. Centralizar el almacenamiento y la trazabilidad de las evidencias documentales (archivos de soporte) que sustentan cada evaluación de seguridad de la información, con metadatos verificables (hash SHA-256, tamaño, tipo MIME, autor y fecha de carga).
2. Proveer el registro estructurado del contexto organizacional (misión, análisis de contexto, mapa de procesos, organigrama, auto-percepción) requerido por la metodología de evaluación del Módulo 1 MSPI.
3. Calcular y exponer la métrica de alcance de procesos (cobertura) con detección explícita de inconsistencias entre procesos totales y procesos en alcance.
4. Ofrecer un mecanismo de inicialización y clonación del levantamiento documental por evaluación, evitando reinicializaciones duplicadas y validando la existencia previa del levantamiento origen al clonar.
5. Exponer un canal interno seguro (API key compartida) que permita a `ms_assessment` y `ms_reporting` integrarse sin necesidad de propagar el JWT del usuario final en llamadas server-to-server.
6. Mantener el microservicio desacoplado de infraestructura mediante arquitectura hexagonal, de forma que el dominio (`domain/model`, `domain/usecase`) no dependa de Spring, JPA ni del mecanismo de almacenamiento físico de archivos (`FileStorageGateway` como puerto).

## 4. Requerimientos iniciales

A partir del código y la documentación (`README.md`, `docs/openapi.yaml`, `docs/MVP-MSPI-CONTRATOS-Y-MER.md`) se identifican los siguientes requerimientos que dieron forma al microservicio:

- **RI-1** — Los archivos deben validarse por tipo MIME permitido (PDF, DOC/DOCX, XLSX, PNG, JPEG), tamaño máximo (20 MB general, 50 MB para `REPORT_OUTPUT`) y coherencia de `relationType`/`relationId`/`contextField` antes de persistirse.
- **RI-2** — Cada archivo almacenado debe registrar su hash SHA-256, calculado durante la escritura en disco (sin doble lectura del stream), para permitir verificación de integridad.
- **RI-3** — El almacenamiento físico de archivos debe organizarse por fecha de carga y por evaluación (`{EVIDENCE_STORAGE_DIR}/{yyyy}/{mm}/{dd}/{assessmentId}/...`), y el acceso a rutas debe validarse contra *path traversal* (normalización + verificación de prefijo contra la raíz configurada).
- **RI-4** — El borrado de un archivo debe ser lógico en base de datos (`deleted_at`) y a la vez intentar el borrado físico en el filesystem; un fallo al borrar el archivo físico no debe interrumpir el flujo (se registra advertencia).
- **RI-5** — El levantamiento documental de una evaluación no puede inicializarse dos veces (`liftingExistsForAssessment`), y la clonación entre evaluaciones exige que el origen exista y el destino aún no tenga levantamiento inicializado.
- **RI-6** — Las rutas `/internal/**` deben ser accesibles sin JWT de usuario, protegidas únicamente por el header `X-Internal-Api-Key`, validado contra un valor configurado (`INTERNAL_API_KEY`); si la clave del servidor no está configurada, la ruta responde `503`.
- **RI-7** — El servicio debe exponer *health checks* (`/actuator/health`, `/actuator/info`) para el arranque orquestado en Docker Compose.
- **RI-8** — El microservicio **no debe** ejecutar DDL automáticamente (`spring.sql.init.mode: never`, `hibernate.ddl-auto: none`); el esquema `evidence` se gestiona por `schema.sql` versionado y aplicado externamente (Docker/DBA).
- **RI-9** — La conexión a PostgreSQL depende obligatoriamente del secreto `DB_CREDENTIAL` (JSON) resuelto vía Infisical; a diferencia de otros microservicios del mismo repositorio, `ms_evidence` **no tiene fallback a H2** — sin `DB_CREDENTIAL` la aplicación no arranca (`DBCredentialConfig` lanza `IllegalStateException`).

## 5. Stack tecnológico (versiones reales verificadas en el código)

| Componente | Versión / detalle | Evidencia |
|---|---|---|
| Lenguaje | Java 21 (toolchain) | `main.gradle`: `JavaLanguageVersion.of(21)` |
| Framework | Spring Boot **4.0.2** | `build.gradle`: `springBootVersion = '4.0.2'` |
| Gestor de build | Gradle **9.3.0** (wrapper) | `main.gradle`: `tasks.named('wrapper') { gradleVersion = '9.3.0' }` |
| Modelo web | Spring MVC (servlet, no reactivo) | `spring-boot-starter-webmvc` en `api-rest/build.gradle` |
| Seguridad | Spring Security + OAuth2 Resource Server (JWT) + filtro propio `InternalApiKeyFilter` | `spring-security-oauth2-resource-server`, `spring-security-oauth2-jose`, `applications/app-service/.../config/InternalApiKeyFilter.java` |
| Persistencia | Spring Data JPA + Hibernate | `spring-boot-starter-data-jpa` en `jpa-repository/build.gradle` |
| Base de datos | PostgreSQL (única; sin H2 de desarrollo) | `runtimeOnly 'org.postgresql:postgresql'`, `DBCredentialConfig` exige `DB_CREDENTIAL` |
| Almacenamiento de archivos | Sistema de archivos local vía `FileStorageGateway` / `LocalFileStorageAdapter` (no S3, no object storage externo) | `applications/app-service/.../storage/LocalFileStorageAdapter.java` |
| Gestión de secretos | Infisical SDK 3.0.2 | `com.infisical:sdk:3.0.2` en `app-service/build.gradle` |
| Multipart | Spring MVC multipart, máx. 20 MB por archivo / 22 MB por request | `application.yaml`: `spring.servlet.multipart` |
| Serialización | Jackson (`com.fasterxml.jackson.core:jackson-databind`) | `app-service/build.gradle` |
| Lombok | 1.18.42 (`@Data`, `@Builder`, `@RequiredArgsConstructor`) | `build.gradle` raíz |
| Pruebas | JUnit 5 (`useJUnitPlatform()`), Mockito (vía `spring-boot-starter-test`), ArchUnit 1.4.1, Spring Security Test | ver detalle en `05-Pruebas.md` |
| Cobertura / calidad | JaCoCo 0.8.14, Pitest (mutation testing) 1.19.0-rc.3 / motor 1.22.0, SonarQube plugin 7.2.2.6593 | `build.gradle`, `main.gradle` |
| Contenedor | `eclipse-temurin:21-jdk-alpine` (build) → `eclipse-temurin:21-jre-alpine` (runtime) | `deployment/Dockerfile` |
| CI/CD | Bitbucket Pipelines, despliegue a Railway | `bitbucket-pipelines.yml` |

## 6. Estructura del proyecto (multi-módulo Gradle)

`settings.gradle` define 6 módulos siguiendo arquitectura hexagonal (Clean Architecture aplicada manualmente por convención de carpetas, sin plugin de generación):

```
MsEvidence (rootProject)
├── domain/model                                   → :model         (entidades y VOs de dominio, puertos/gateways — sin dependencias de framework)
├── domain/usecase                                  → :usecase       (casos de uso — solo depende de :model y :common)
├── infrastructure/helpers/common                   → :common        (DTOs de respuesta, excepciones de dominio compartidas)
├── infrastructure/driven-adapters/jpa-repository    → :jpa-repository (adaptador de persistencia JPA/PostgreSQL — implementa EvidencePersistenceGateway)
├── infrastructure/entry-points/api-rest             → :api-rest      (controladores REST públicos e internos, DTOs, manejo de excepciones)
└── applications/app-service                         → :app-service   (módulo ejecutable Spring Boot, `MainApplication`, wiring, seguridad, adaptador de almacenamiento local)
```

A diferencia de `ms_iam` (que separa `rest-consumer`, `service` y `brevo-sender` como módulos independientes), `ms_evidence` es un proyecto más compacto: **no tiene módulo `rest-consumer`** (no consume APIs externas de terceros) y el adaptador de almacenamiento de archivos (`LocalFileStorageAdapter`, `FileStorageProperties`) vive directamente dentro de `applications/app-service` en lugar de un módulo `driven-adapters` dedicado — una particularidad de diseño real observada en el código y no un módulo `filesystem` independiente (el `README.md` lo menciona como aspiracional en su diagrama de estructura, pero el paquete real es `co.com.mspi.storage` bajo `app-service`).

## 7. Recursos y planificación del desarrollo

No se encontró en el repositorio de `ms_evidence` un archivo `ROADMAP.md`, `CHANGELOG.md` ni un plan de iteraciones específico del microservicio. La planificación general del proyecto de grado se documenta a nivel de todo el sistema MSPI en:

- `docker-config/docs/PLAN_TRABAJO_MSPI_v2.md` — plan de trabajo global del proyecto.
- `docker-config/docs/README.md` e `INSTRUCCIONES-EQUIPO.md` — guía de orquestación y coordinación del equipo.
- `docker-config/docs/backend/MER-SEED-LINEA-BASE.sql` — datos semilla del catálogo de instrumentos, incluyendo referencias directas a `evidence.process_scope_metric` (ítem 43 del catálogo diagnóstico: "registrar # total de procesos, # de procesos en alcance y % de avance").
- `ms_evidence/docs/MVP-MSPI-CONTRATOS-Y-MER.md` — documento de contratos entre microservicios y cambios al MER, enfocado principalmente en el contrato `ms_iam` ↔ `ms_org`, sin una sección dedicada a `ms_evidence`; esto sugiere que la evolución de contrato de `ms_evidence` se documentó mayormente en su propio `README.md` y `docs/openapi.yaml`.
- `ms_evidence/docs/openapi.yaml` — especificación OpenAPI 3.1.0 exhaustiva (1107 líneas) que actúa como documento de diseño y contrato de API del microservicio.

Dado que no existe evidencia de un cronograma o backlog propio de `ms_evidence`, este documento declara explícitamente esa ausencia en lugar de inventar fechas o hitos.

## 8. Actores interesados (stakeholders) inferidos del dominio

| Actor | Interés en `ms_evidence` |
|---|---|
| Usuario final autenticado (evaluador de la organización) | Consumidor de `/assessments/{id}/context`, `/assessments/{id}/process-scope-metric`, `/assessments/{id}/lifting-document-deliveries`, `/assessments/{id}/files` (JWT) |
| `ms_assessment` | Consumidor S2S de `/internal/assessments/{id}/lifting/init`, `/lifting/clone/{target}`, `/evidence-files`, `/context` mediante `X-Internal-Api-Key` |
| `ms_reporting` | Consumidor S2S de `/internal/assessments/{id}/report-outputs` (subida) y `/internal/files/{id}/download` (descarga interna de PDF/XLSX generados) |
| Frontend | Consumidor de todas las rutas públicas con JWT: contexto, métricas, entregas y archivos |
| Equipo DevOps / DBA | Responsable de aplicar `schema.sql` sobre el esquema `evidence` y de aprovisionar el volumen persistente `EVIDENCE_STORAGE_DIR` |
| Keycloak (IdP) | Proveedor de identidad; `ms_evidence` actúa como *Resource Server* OAuth2, validando JWT emitidos por el realm `iam` |
| Auditor ISO/IEC 27001 (usuario final indirecto) | Beneficiario último del control: las evidencias documentales cargadas y su hash de integridad sustentan la evaluación de cumplimiento |
