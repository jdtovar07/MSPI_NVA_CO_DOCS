# ms_reporting — Planificación

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_reporting` |
| Sistema | MSPI (Modelo de Seguridad y Privacidad de la Información — ISO/IEC 27001) |
| Fecha del documento | 2026-08-19 |
| Alcance | Fase de planificación del microservicio `ms_reporting` dentro de la arquitectura de microservicios MSPI |

---

## 1. Contexto del sistema MSPI

MSPI es un sistema de gestión de seguridad de la información construido como un conjunto de microservicios Java/Spring independientes que colaboran vía HTTP/REST y comparten un modelo de datos lógico (`docs/proyecto/DB-MER.txt` en el repositorio contenedor) particionado por esquema de base de datos (uno por microservicio: `iam`, `org`, `catalog`, `evidence`, `assessment`, `reporting`, `audit`, …). El repositorio contenedor `MSPI_NVA_CO_MR_BACK` agrupa cada microservicio como carpeta independiente, y `docker-config/` centraliza la orquestación local con Docker Compose (`docker-config/docker/docker-compose.apps.yml`).

`ms_reporting` es el microservicio del **Módulo 9 — Reportes y exportación** (identificado en el propio `README.md` con las historias de usuario `HU-REP-01` a `HU-REP-04`). No es un servicio fundacional (no bloquea el arranque de otros), sino un **orquestador de generación documental**: recibe una solicitud de reporte, delega en `ms_assessment` la obtención de los datos consolidados de una evaluación, arma el documento (PDF/Excel) localmente con librerías Java y LibreOffice, y delega en `ms_evidence` el almacenamiento definitivo del artefacto binario. `ms_reporting` no posee lógica de negocio de evaluación ni de evidencias: es un servicio de "última milla" que transforma datos ya calculados por otros microservicios en documentos descargables.

## 2. Alcance del microservicio

`ms_reporting` cubre exclusivamente la responsabilidad de negocio de **generación asíncrona de reportes de diagnóstico ISO 27001/MSPI en formato PDF y Excel**. Concretamente, según el código verificado:

- **Creación de jobs de reporte** (`POST /reports/jobs`) para una evaluación (`assessmentId`) y un tipo de reporte (`ReportType`), con respuesta inmediata `202 Accepted` y procesamiento en segundo plano (`CompletableFuture.runAsync`).
- **Ocho tipos de reporte** definidos en el enum `ReportType`: `FULL_DIAGNOSTIC_PDF`, `EXCEL_INSTRUMENT_EXPORT`, `GAP_LIST_PDF`, `GAP_LIST_XLSX`, `COMPARATIVE_DIAGNOSTIC_PDF`, `COMPARATIVE_DIAGNOSTIC_XLSX`, `DIAGNOSTIC_WIDGET_PNG`, `DIAGNOSTIC_WIDGET_PDF` — de los cuales el motor de generación (`ProcessReportJobUseCase`) implementa realmente `FULL_DIAGNOSTIC_PDF`, `EXCEL_INSTRUMENT_EXPORT`, `GAP_LIST_PDF`, `GAP_LIST_XLSX`, `COMPARATIVE_DIAGNOSTIC_PDF` y `COMPARATIVE_DIAGNOSTIC_XLSX`; los dos tipos `DIAGNOSTIC_WIDGET_*` existen como valores del enum y en el catálogo conceptual pero **no tienen rama de generación implementada** (caerían en `IllegalStateException` si se solicitaran).
- **Relleno de la plantilla oficial `plantilla-portada-2022.xlsx`** (hoja **PORTADA** ISO 27001:2022: dominios A.5–A.8, PHVA por cláusulas C.4–C.10, NIST CSF 2.0, logos) usando Apache POI, sobrescribiendo valores de ejemplo con el tablero diagnóstico.
- **Conversión XLSX → PDF vía LibreOffice** (`soffice --headless`) para el reporte `FULL_DIAGNOSTIC_PDF`, de forma que el PDF final sea visualmente idéntico al Excel generado (gráficos incluidos), en lugar de reconstruir el diseño con una librería de PDF pura.
- **Reportes de brechas** (`GAP_LIST_PDF` / `GAP_LIST_XLSX`) construidos con `OpenPDF` (paquete `com.lowagie.text`, antiguo iText) y Apache POI a partir de la respuesta de `GET /internal/assessments/{id}/gaps` de `ms_assessment`.
- **Reportes comparativos multi-evaluación** (`POST /reports/comparative/jobs`, regla de negocio `#116`: mínimo 2 evaluaciones, todas de la misma organización).
- **Persistencia del ciclo de vida del job** (`PENDING → RUNNING → COMPLETED/FAILED`, con `progressPct`, `errorMessage`, `outputFileId`) en el esquema PostgreSQL `reporting`.
- **Descarga del artefacto** (`GET /reports/jobs/{jobId}/download`), sirviendo primero desde una caché local en disco del contenedor y, si no existe, desde `ms_evidence` mediante streaming.
- **Archivado en `ms_evidence`** del artefacto generado como evidencia de tipo `REPORT_OUTPUT`, de forma no bloqueante (si falla el archivado, el job igual se marca `COMPLETED` porque el artefacto ya quedó disponible localmente).

Quedan **fuera de alcance** de `ms_reporting`: el cálculo de los indicadores de diagnóstico (dominios ISO, PHVA, madurez, NIST, brechas) — responsabilidad de `ms_assessment`, que expone el *bundle* ya calculado —; el almacenamiento canónico de archivos — responsabilidad de `ms_evidence` —; la gestión de catálogos de escalas — responsabilidad de `ms_catalog`, consumida solo como referencia opcional (`GET /catalog/scales/published`); y la autenticación de usuarios — delegada a Keycloak / `ms_iam` vía JWT.

## 3. Objetivos

1. Desacoplar la generación de documentos (proceso potencialmente lento: E/S de plantilla, invocación a un proceso externo LibreOffice, llamadas HTTP a otros microservicios) del ciclo de vida de la petición HTTP del cliente, mediante un patrón asíncrono de "job" con estados y `202 Accepted`.
2. Producir un PDF de diagnóstico **fiel** a la plantilla institucional `plantilla-portada-2022.xlsx` (logos MinTIC y gráficos), convirtiendo el Excel diligenciado con LibreOffice en lugar de dibujar el PDF desde cero.
3. Reutilizar el `report-export-bundle` ya consolidado por `ms_assessment` como única fuente de datos para todos los tipos de reporte de diagnóstico, evitando que `ms_reporting` reimplemente cálculos de score, banda de madurez o efectividad por dominio.
4. Mantener el microservicio desacoplado de infraestructura mediante arquitectura hexagonal: el dominio (`domain/model`, `domain/usecase`) no depende de Spring, JPA ni de detalles de LibreOffice o Apache POI más allá de las clases de "engine" del propio `usecase` (aceptado como excepción pragmática, ver `03-Diseno.md`).
5. Ofrecer trazabilidad de cada job (estado, progreso, mensaje de error, fecha de solicitud/inicio/fin) consultable por el cliente sin necesidad de mantener una conexión abierta.
6. Garantizar que el archivado en `ms_evidence` sea *best effort*: un fallo del microservicio de evidencias no debe impedir que el usuario descargue el reporte que ya se generó y quedó disponible localmente.

## 4. Requerimientos iniciales

A partir del código y `docs/openapi.yaml` se identifican los siguientes requerimientos que dieron forma al microservicio:

- **RI-1** — Toda solicitud de reporte debe responder de inmediato (`202 Accepted`) con el job en estado `PENDING`; el procesamiento real ocurre en un hilo de un `ThreadPoolTaskExecutor` dedicado (`reportJobExecutor`, `corePoolSize=2`, `maxPoolSize=4`, `queueCapacity=25`).
- **RI-2** — El reporte de diagnóstico completo (`FULL_DIAGNOSTIC_PDF`/`EXCEL_INSTRUMENT_EXPORT`) debe limitarse a la hoja **PORTADA** de la plantilla oficial; el `README.md` es explícito: "El archivo generado no incluye las hojas 2–9".
- **RI-3** — Debe existir una vía de conversión Excel→PDF que preserve gráficos y formato exacto de la plantilla, resuelta con LibreOffice en modo *headless* como proceso externo, configurable por `LIBREOFFICE_PATH` y desactivable con `REPORT_PDF_CONVERSION_ENABLED=false`.
- **RI-4** — Los reportes comparativos requieren mínimo 2 evaluaciones y todas deben pertenecer a la misma organización (`CreateComparativeReportJobUseCase`, validado contra `organizationId` de cada `assessment` obtenido del *bundle*).
- **RI-5** — El servicio no debe bloquear la entrega del reporte al usuario por fallos de terceros: el archivado en `ms_evidence` (`ReportOutputEvidenceArchiver`) captura cualquier `RuntimeException` y continúa sin `outputFileId`.
- **RI-6** — Debe existir una vía de descarga que funcione incluso si el archivado remoto falló, mediante una caché local en el sistema de archivos del contenedor (`FileSystemReportOutputStorage`, `REPORT_OUTPUT_DIR`).
- **RI-7** — Las llamadas salientes a `ms_assessment`, `ms_evidence` y `ms_catalog` deben autenticarse con una clave interna compartida (`X-Internal-Api-Key` / `INTERNAL_API_KEY`), distinta del JWT de usuario final.
- **RI-8** — El microservicio no debe ejecutar DDL automáticamente (`spring.sql.init.mode: never`, `hibernate.ddl-auto: none`); el esquema `reporting` se gestiona con scripts SQL versionados (`schema.sql`, replicado en `docker-config/docker/postgres/init/`).
- **RI-9** — El servicio debe exponer *health checks* (`/actuator/health`, `/actuator/info`) consumidos por el `HEALTHCHECK` de Docker y por Docker Compose.

## 5. Stack tecnológico (versiones reales verificadas en el código)

| Componente | Versión / detalle | Evidencia |
|---|---|---|
| Lenguaje | Java 21 (toolchain) | `main.gradle`: `JavaLanguageVersion.of(21)` |
| Framework | Spring Boot **4.0.2** | `build.gradle`: `springBootVersion = '4.0.2'` |
| Build | Gradle multi-módulo, wrapper **9.3.0** | `settings.gradle`, `main.gradle`: `tasks.named('wrapper') { gradleVersion = '9.3.0' }` |
| Persistencia | Spring Data JPA + PostgreSQL (esquema `reporting`) | `jpa-repository/build.gradle`, `application.yaml` |
| Cliente HTTP saliente | `RestClient` (Spring 6/Boot 4), 3 beans (`msAssessmentRestClient`, `msCatalogRestClient`, `msEvidenceRestClient`) | `RestConsumerConfig.java` |
| Seguridad | Spring Security OAuth2 Resource Server (JWT vía Keycloak) | `SecurityConfig.java` |
| Generación PDF | **OpenPDF 1.3.39** (`com.github.librepdf:openpdf`, fork libre de iText, paquete `com.lowagie.text`) | `domain/usecase/build.gradle` |
| Generación/relleno Excel | **Apache POI 5.2.5** (`poi-ooxml`) | `domain/usecase/build.gradle` |
| Conversión XLSX→PDF | **LibreOffice** (`soffice --headless`) vía `ProcessBuilder` con `Redirect.DISCARD` y perfil `UserInstallation` aislado | `LibreOfficePdfConverter.java` |
| Procesamiento asíncrono | `CompletableFuture.runAsync` + `ThreadPoolTaskExecutor` nombrado (`reportJobExecutor`) | `ReportJobAsyncConfig.java`, `ReportJobApi.java` |
| Serialización JSON | Jackson (`jackson-databind`) | `domain/usecase/build.gradle`, `JacksonConfig.java` |
| Gestión de secretos | Infisical SDK 3.0.2 | `applications/app-service/build.gradle`: `com.infisical:sdk:3.0.2` |
| Lombok | 1.18.42 | `build.gradle` raíz |
| Cobertura | JaCoCo 0.8.14, umbral 80% de instrucciones (`jacocoTestCoverageVerification`) | `main.gradle` |
| Mutation testing | Pitest 1.19.0-rc.3 / 1.22.0 (plugin declarado, sin evidencia de ejecución en CI) | `main.gradle` |
| Calidad estática | Plugin SonarQube 7.2.2.6593 (configurado, sin evidencia de conexión a CI) | `build.gradle` raíz |
| Contenerización | Docker multi-stage, `eclipse-temurin:21-jdk-alpine` (build) → `eclipse-temurin:21-jre-jammy` (runtime) + LibreOffice Calc | `deployment/Dockerfile`, `deployment/docker-entrypoint.sh` |
| Documentación de API | OpenAPI 3.1.0 estático (`docs/openapi.yaml`), sin `springdoc-openapi` en las dependencias (no hay Swagger UI servido en runtime) | verificado: ninguna dependencia `springdoc` en los `build.gradle` |

## 6. Actores del sistema

| Actor | Naturaleza | Interacción con `ms_reporting` |
|---|---|---|
| Usuario autenticado (Evaluador, Revisor, AdminInstrumento, AdminSistema, Lector) | Humano, vía frontend | Crea jobs de reporte y descarga el resultado; según `SecurityConfig`, cualquier usuario autenticado (sin restricción de rol adicional a nivel de `ms_reporting`) puede acceder a `/reports/**` |
| `ms_assessment` (:8084) | Microservicio interno | Provee el *bundle* de datos de diagnóstico y la lista de brechas; llamado con `X-Internal-Api-Key` |
| `ms_evidence` (:8086) | Microservicio interno | Recibe el archivo generado como evidencia `REPORT_OUTPUT`; sirve la descarga cuando la caché local no tiene el archivo |
| `ms_catalog` (:8085) | Microservicio interno | Fuente de la escala de evaluación publicada (`GET /catalog/scales/published`); su gateway (`CatalogGateway`) existe en el dominio pero **no se invoca actualmente** desde `ProcessReportJobUseCase` (ver hallazgo en `02-Analisis.md`) |
| Keycloak | Identity Provider externo | Emite y firma los JWT validados por `SecurityConfig` (`spring.security.oauth2.resourceserver.jwt`) |
| Infisical | Gestor de secretos externo | Provee credenciales de base de datos y otros secretos en producción (`InfisicalConfig`, `DBCredentialConfig`) |
| Sistema operativo del contenedor | Infraestructura | Ejecuta `soffice --headless` como proceso hijo para la conversión PDF |

## 7. Recursos y planificación (evidencia disponible)

No existe en el repositorio evidencia de un plan de proyecto formal (cronograma, EDT, asignación de horas) específico para `ms_reporting`; el contexto de planificación agregada del sistema MSPI se documenta a nivel de repositorio contenedor en `docker-config/docs/PLAN_TRABAJO_MSPI_v2.md` y `docker-config/docs/proyecto/Historias_Usuario_MSPI_v2.md` (no incluidos en el alcance de este microservicio). Como evidencia indirecta de planificación incremental dentro del propio código:

- El README enumera explícitamente las historias de usuario que originaron el módulo: `HU-REP-01` (diagnóstico completo PDF), `HU-REP-02` (export Excel del instrumento), `HU-REP-03` (lista de brechas PDF/Excel) y `HU-REP-04` (comparativo temporal), y el comentario `#116` en `CreateComparativeReportJobUseCase` referencia el número de tarjeta/ticket de la regla de mínimo 2 evaluaciones.
- Los seeds `data.sql` / `MER-SEED-REPORTING.sql` aún referencian metadatos Jasper / libro multi-hoja históricos; el motor activo es `MspiPortadaTemplateFiller` + `plantilla-portada-2022.xlsx` (classpath). Las tablas de plantillas en BD son descriptivas, no configuran el filler.
- El microservicio consumidor documentado del contrato de `ms_reporting` es el microfrontend `mf_reports` (ver `Documentacion-Frontend/mf_reports/`), que integra los mismos endpoints (`/reports/jobs`, `/reports/comparative/jobs`) descritos en este documento.

## 8. Riesgos identificados

| Riesgo | Evidencia en código | Mitigación existente |
|---|---|---|
| Dependencia de LibreOffice en runtime (resuelta en la imagen Docker Jammy; pendiente solo fuera de contenedor) | `deployment/Dockerfile` instala `libreoffice-calc` + fuentes; `LIBREOFFICE_PATH` opcional si `soffice` no está en PATH | En Docker, `FULL_DIAGNOSTIC_PDF` usa `/usr/bin/soffice`; `REPORT_PDF_CONVERSION_ENABLED=false` sigue permitiendo deshabilitar la ruta |
| Procesamiento en memoria sin cola persistente | README: "No aplica (procesamiento en memoria con `CompletableFuture`, sin cola externa)" | Job persistido en PostgreSQL antes de iniciar el procesamiento asíncrono, permitiendo reconsulta de estado aunque el hilo se pierda; no hay reintento automático tras caída del proceso |
| Archivado a `ms_evidence` no transaccional con la generación | `ReportOutputEvidenceArchiver.archive` atrapa `RuntimeException` y retorna `Optional.empty()` | El job se marca `COMPLETED` igualmente porque el artefacto sigue disponible en `FileSystemReportOutputStorage` |
| Pool de hilos fijo y pequeño (`maxPoolSize=4`, `queueCapacity=25`) ante picos de generación de reportes (proceso costoso por invocar LibreOffice) | `ReportJobAsyncConfig` | Ninguna mitigación adicional visible (sin *backpressure* explícito ni *rate limiting*) |
| Seeds de base de datos desalineados con la implementación (plantillas Jasper vs. plantilla PORTADA única) | `data.sql` / `MER-SEED-REPORTING.sql` | Ninguna; riesgo de confusión para nuevos desarrolladores, documentado aquí |
