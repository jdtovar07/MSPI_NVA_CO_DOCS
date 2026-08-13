# ms_assessment — Planificación

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_assessment` |
| Sistema | MSPI (Modelo de Seguridad y Privacidad de la Información — ISO/IEC 27001) |
| Fecha del documento | 2026-08-18 |
| Alcance | Fase de planificación del microservicio `ms_assessment` dentro de la arquitectura de microservicios MSPI |

---

## 1. Contexto del sistema MSPI

MSPI es un sistema de gestión de seguridad de la información construido como un conjunto de microservicios Java/Spring independientes que colaboran vía HTTP/REST, particionados por esquema de base de datos (uno por microservicio: `iam`, `org`, `catalog`, `evidence`, `assessment`, …). El repositorio contenedor `MSPI_NVA_CO_MR_BACK` agrupa cada microservicio como carpeta independiente, y `docker-config/` centraliza la orquestación local con Docker Compose.

`ms_assessment` es el **motor de evaluaciones de madurez de seguridad de la información** del sistema: materializa, a partir de un catálogo versionado (`ms_catalog`), una instancia evaluable (snapshot) por cada evaluación creada, permite calificar controles/PHVA/madurez/NIST, y calcula on-read (sin persistir resultados) las agregaciones de rollup, resumen y diagnóstico que consumen el frontend y `ms_reporting`.

## 2. Alcance del microservicio

`ms_assessment` cubre exclusivamente la responsabilidad de negocio de **ciclo de vida, calificación y diagnóstico de evaluaciones**. Concretamente, según el propio `README.md` y la estructura de casos de uso (`domain/usecase`):

- **Ciclo de vida de la evaluación** (Módulo M1): creación en estado `BORRADOR` con materialización de snapshots desde `ms_catalog`, edición de metadatos, asignación de tipo de orden territorial (`entity_order_type_code`), publicación (`BORRADOR` → `CERRADA`) y clonación.
- **Áreas y temas organizacionales** (M2): áreas evaluativas (snapshot de presets de `ms_catalog`) y temas/procesos con responsable (steward) por defecto.
- **Controles administrativos y técnicos** (M3/M4): snapshot del árbol de controles del Anexo A, calificación (`score_status`, `score_value`), evidencia textual, brecha, recomendación, estado del control y resolución de responsable (steward) por control (heredado del área o `CUSTOM`).
- **Ciclo PHVA** (M5): requisitos Planear-Hacer-Verificar-Actuar, con calificación manual o heredada de un control/rollup. Con plantilla **v2** el snapshot trae **7 cláusulas** (`C.4`–`C.10`) y el avance usa pesos/caps **56/16/14/14**.
- **Madurez MSPI** (M6): requisitos de madurez por nivel (1–5), con matriz de cumplimiento, nivel alcanzado y bloqueos hacia el siguiente nivel (CMMI-like).
- **NIST CSF / Ciber** (M7): filas del marco NIST Cybersecurity Framework mapeadas a funciones y subcategorías, con resumen por función **dinámico** (deriva las funciones presentes en el snapshot; CSF 2.0 incluye **GV/Gobernar** + 5 restantes = 6 ejes).
- **Diagnóstico y brechas** (M8): efectividad por dominio ISO, tablero diagnóstico agregado (PHVA + madurez + NIST + auto-percepción) y listado de brechas priorizadas (score < umbral, HU-REP-03).
- **API interna de reporting** (M9, consumida por `ms_reporting`): bundle de exportación agregado y listado de brechas vía `X-Internal-Api-Key`.

Quedan **fuera de alcance** de `ms_assessment` (responsabilidad de otros microservicios): la definición del catálogo de controles/PHVA/madurez/NIST y sus reglas (`ms_catalog`), la gestión de organizaciones (`ms_org`), la carga y almacenamiento de evidencias documentales (`ms_evidence`), la identidad y auditoría centralizada (`ms_iam`), y la generación de reportes/exportables definitivos (`ms_reporting`). `ms_assessment` únicamente **consume** esos servicios y persiste su propio esquema `assessment`.

## 3. Objetivos

1. Materializar, al crear una evaluación, una copia inmutable (snapshot) del árbol de controles, PHVA, madurez y NIST vigente en `ms_catalog`, de forma que la evaluación no cambie retroactivamente si el catálogo se actualiza después.
2. Permitir calificar cada elemento evaluable (control, ítem PHVA, requisito de madurez, ítem NIST) con un modelo uniforme `score_status` (`SCORED`/`NA`) + `score_value` (0–100), y encadenar reglas de negocio de completitud (evidencia, brecha, recomendación) definidas por el catálogo.
3. Calcular on-read (sin tablas de resultados propias) los agregados de rollup jerárquico, resumen PHVA/madurez/NIST, efectividad por dominio y tablero diagnóstico, evitando duplicar o desincronizar datos calculados.
4. Resolver de forma centralizada el "responsable" (steward) de cada control, por herencia desde el área/tema o por override explícito por control.
5. Registrar auditoría de eventos de negocio relevantes (publicación, asignación de tipo de entidad) en la bitácora centralizada de `ms_iam`, de forma *best-effort* (sin bloquear la operación principal si la auditoría falla).
6. Exponer un contrato interno estable (`/internal/assessments/**`, protegido con API key compartida) para que `ms_reporting` construya reportes sin duplicar la lógica de cálculo.
7. Mantener el microservicio desacoplado de infraestructura mediante arquitectura hexagonal, de forma que el dominio (`domain/model`, `domain/usecase`) no dependa de Spring, JPA ni de los detalles HTTP de los servicios externos que consume.

## 4. Requerimientos iniciales

A partir del código, `docs/openapi.yaml` y `docs/MVP-MSPI-CONTRATOS-Y-MER.md` se identifican los siguientes requerimientos que dieron forma al microservicio:

- **RI-1** — Toda evaluación nace en estado `BORRADOR` y solo puede transicionar a `CERRADA` mediante publicación explícita; una vez `CERRADA` no admite edición (`PatchControlScoreUseCase`, `PublishAssessmentUseCase`).
- **RI-2** — Publicar exige que la evaluación tenga asignado `entity_order_type_code` (tipo de orden territorial) y un `rowVersion` coincidente con el estado actual (control de concurrencia optimista, HTTP 409 si no coincide).
- **RI-3** — Toda calificación numérica debe pertenecer a la escala publicada por `ms_catalog` (`GET /catalog/.../scale-levels`) — valores típicos `0,20,40,60,80,100` — o ser `NA`.
- **RI-4** — Marcar un control como `COMPLETADO` obliga, según las reglas del catálogo (`ControlRuleInfo`), a que existan evidencia, brecha y/o recomendación (esta última condicionada a un umbral configurable `THRESHOLD`).
- **RI-5** — El cálculo de agregaciones (`rollup`, resúmenes PHVA/madurez/NIST, diagnóstico, brechas) es **on-read**: no existen tablas de resultados persistidos; toda evaluación se recalcula bajo demanda a partir de las respuestas capturadas y el snapshot.
- **RI-6** — Debe existir un canal de auditoría hacia `ms_iam` (`POST /internal/audit/events`) para eventos de negocio (`ASSESSMENT_PUBLISHED`, asignación de tipo de entidad), protegido con `X-Internal-Api-Key`, y tolerante a fallos (no debe abortar la operación de negocio si la auditoría no responde).
- **RI-7** — Debe existir una API interna (`/internal/assessments/**`) sin JWT pero protegida por `X-Internal-Api-Key`, consumida por `ms_reporting`, para exponer el bundle de exportación y las brechas sin requerir que ese microservicio reimplemente el cálculo.
- **RI-8** — El servicio debe exponer *health checks* (`/actuator/health`, `/actuator/info`) para orquestación por Docker Compose/Railway.
- **RI-9** — El identificador del usuario autenticado no proviene directamente del JWT (`sub`), sino que se resuelve contra el perfil espejo de `ms_iam` (`IamUserGateway.resolveInternalUserId`, usado por `CurrentUserResolver`), lanzando `IamServiceException` si el usuario no está registrado.

## 5. Stack tecnológico (versiones reales verificadas en el código)

| Componente | Versión / detalle | Evidencia |
|---|---|---|
| Lenguaje | Java 21 (toolchain) | `main.gradle`: `JavaLanguageVersion.of(21)` |
| Framework | Spring Boot **4.0.2** | `build.gradle`: `springBootVersion = '4.0.2'` |
| Gestor de build | Gradle **9.3.0** (wrapper) | `main.gradle`: `tasks.named('wrapper') { gradleVersion = '9.3.0' }` |
| Modelo web | Spring MVC (servlet, no reactivo) | `spring-boot-starter-webmvc` en `api-rest` y `app-service` |
| Seguridad | Spring Security + OAuth2 Resource Server (JWT) | `spring-security-oauth2-resource-server`, `spring-security-oauth2-jose` |
| Persistencia | Spring Data JPA + Hibernate | `spring-boot-starter-data-jpa` en `jpa-repository/build.gradle` |
| Base de datos | PostgreSQL (esquema `assessment`) | `runtimeOnly 'org.postgresql:postgresql'`; sin motor H2 declarado en ningún módulo |
| Gestión de secretos | Infisical SDK 3.0.2 | `com.infisical:sdk:3.0.2` en `app-service/build.gradle` |
| Cliente HTTP saliente | `RestClient` de Spring (no `RestTemplate`/`WebClient`) | `RestConsumerConfig`, `RestClientConfig` (`RestClient.builder()`) |
| Serialización | Jackson (`jackson-databind`) | `app-service/build.gradle`, `rest-consumer/build.gradle` |
| Validación | Bean Validation | `spring-boot-starter-validation` en `api-rest/build.gradle` |
| Observabilidad | Spring Boot Actuator | `spring-boot-starter-actuator` en `api-rest/build.gradle` |
| Lombok | 1.18.42 | `build.gradle` raíz |
| Pruebas | JUnit 5, Mockito, AssertJ (vía `spring-boot-starter-test`), Spring Security Test, ArchUnit 1.4.1 | ver detalle en `05-Pruebas.md` |
| Cobertura / calidad | JaCoCo 0.8.14, Pitest (mutation testing) 1.19.0-rc.3/1.22.0, SonarQube plugin 7.2.2.6593 | `build.gradle`, `main.gradle` |
| Contenedor | `eclipse-temurin:21-jdk-alpine` (build) → `eclipse-temurin:21-jre-alpine` (runtime) | `deployment/Dockerfile` |
| CI/CD | Bitbucket Pipelines, despliegue a Railway | `bitbucket-pipelines.yml` |
| Contrato API | OpenAPI 3.1.0 (`docs/openapi.yaml`, 2574 líneas) | archivo del repositorio |

No se encontraron dependencias de mensajería/eventos (Kafka, RabbitMQ), caché (Redis) ni motores reactivos (WebFlux/R2DBC): toda la comunicación entre microservicios es HTTP/REST síncrona.

## 6. Estructura del proyecto (multi-módulo Gradle)

`settings.gradle` define **7 módulos** siguiendo arquitectura hexagonal (Clean Architecture aplicada manualmente por convención de carpetas, sin plugin generador):

```
MsAssessment (rootProject)
├── domain/model        → :model          (entidades, comandos, gateways/puertos — sin dependencias declaradas)
├── domain/usecase       → :usecase        (casos de uso — depende de :model y :common)
├── infrastructure/helpers/common → :common (DTOs de respuesta, excepciones de dominio compartidas)
├── infrastructure/driven-adapters/jpa-repository → :jpa-repository (persistencia PostgreSQL)
├── infrastructure/driven-adapters/rest-consumer  → :rest-consumer  (clientes ms_org, ms_catalog, ms_evidence, ms_iam)
├── infrastructure/entry-points/api-rest → :api-rest (controladores REST públicos e internos, DTOs, seguridad de capa web)
└── applications/app-service → :app-service (módulo ejecutable Spring Boot, `MainApplication`, wiring/config)
```

A diferencia de `ms_iam` (que separa `:service` para orquestación compleja y añade `:brevo-sender`), `ms_assessment` no tiene módulo de servicio adicional: los casos de uso en `:usecase` orquestan directamente los gateways, sin una capa intermedia de "servicio de aplicación".

## 7. Recursos y planificación del desarrollo

No se encontró en el repositorio de `ms_assessment` un archivo `ROADMAP.md`, `CHANGELOG.md` ni un plan de iteraciones específico del microservicio. La planificación detallada de módulos (M1–M9) se documenta implícitamente en el propio `README.md` (tabla "Módulos funcionales M1–M8") y en las historias de usuario referenciadas por código (`HU-ADM-*`, `HU-TEC-*`, `HU-PHVA-*`, `HU-MAD-*`, `HU-CIB-*`, `HU-DIAG-*`, `HU-REP-03`, `HU-AR-01`), visibles como comentarios Javadoc en las clases de caso de uso (p. ej. `ListGapsUseCase`: *"HU-REP-03 — brechas on-read"*). No existe un archivo de historias de usuario propio dentro de `ms_assessment/docs`; las referencias apuntan a un backlog gestionado a nivel de todo el proyecto MSPI (fuera de este repositorio de microservicio).

Se declara explícitamente esta ausencia en lugar de inventar fechas, hitos o asignación de recursos: no hay evidencia en el repositorio de un cronograma, backlog priorizado ni dotación de equipo específica para `ms_assessment`.

Documento de referencia funcional local:

- `docs/MVP-MSPI-CONTRATOS-Y-MER.md` — describe principalmente el contrato `ms_iam` ↔ `ms_org`, pero incluye en su sección "Próximos pasos" la referencia `ms_assessment: HU-MVP-009 (consulta resultado de evaluación de la organización)`, confirmando que el microservicio se planificó como parte de una hoja de ruta incremental del MVP del sistema MSPI.
- `docs/openapi.yaml` — contrato formal de 27 operaciones REST agrupadas en 10 tags funcionales (M1 a M9), usado como fuente de verdad para el diseño de API (ver `03-Diseno.md`).

## 8. Actores interesados (stakeholders) inferidos del dominio

| Actor | Interés en `ms_assessment` |
|---|---|
| Evaluador (rol de negocio consumidor de `/assessments/**`) | Crea, edita, califica y publica evaluaciones de madurez de su organización |
| `ms_org` | Proveedor de `GET /organizations/{id}`, consultado para validar la organización al crear una evaluación |
| `ms_catalog` | Proveedor de la plantilla activa, árbol de controles, PHVA, madurez, NIST, presets de áreas, dominios ISO, escala y reglas — fuente de todo lo que se "snapshotea" al crear una evaluación |
| `ms_evidence` | Consumidor/proveedor de levantamiento documental por evaluación (`init`/`clone` de *lifting*), adjuntos por control y contexto de auto-percepción usado en el tablero diagnóstico |
| `ms_iam` | Sumidero de auditoría (`POST /internal/audit/events`) y proveedor de resolución de identidad interna (`IamUserGateway`) para mapear el `sub` del JWT a un `userId` interno |
| `ms_reporting` (Módulo 9) | Consumidor S2S de `/internal/assessments/**` (bundle de exportación y brechas) vía `X-Internal-Api-Key`, sin pasar por JWT |
| Keycloak (IdP) | Emisor de los JWT que autentican la API pública (`/assessments/**`) |
| Equipo DevOps / DBA | Responsable de aplicar `schema.sql` (el microservicio **no** ejecuta DDL automáticamente, ver `03-Diseno.md`/`06-Implementacion-Despliegue.md`) |
