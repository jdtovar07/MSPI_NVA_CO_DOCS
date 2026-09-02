# ms_iam — Planificación

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_iam` |
| Sistema | MSPI (Modelo de Seguridad y Privacidad de la Información — ISO/IEC 27001) |
| Fecha del documento | 2026-08-18 |
| Alcance | Fase de planificación del microservicio `ms_iam` dentro de la arquitectura de microservicios MSPI |

---

## 1. Contexto del sistema MSPI

MSPI es un sistema de gestión de seguridad de la información construido como un conjunto de microservicios Java/Spring independientes que colaboran vía HTTP/REST y comparten un modelo de datos lógico (`DB-MER.txt`) particionado por esquema de base de datos (uno por microservicio: `iam`, `org`, `catalog`, `evidence`, `assessment`, `audit`, …). El repositorio contenedor `MSPI_NVA_CO_MR_BACK` agrupa cada microservicio como carpeta independiente (`ms_iam`, `ms_org`, `ms_catalog`, `ms_evidence`, `ms_assessment`, `ms_audit`, `ms_admin`, …), y `docker-config/` centraliza la orquestación local con Docker Compose (`docker-config/docker/docker-compose.apps.yml`), incluyendo Keycloak como Identity Provider.

`ms_iam` es el microservicio de **Identidad y Acceso** (IAM) del sistema. Es un servicio fundacional: los demás microservicios dependen de él para autenticación (emisión/validación de JWT vía Keycloak) y para la bitácora centralizada de auditoría (`iam.audit_log`), razón por la cual en `docker-compose.apps.yml` los demás servicios declaran `depends_on: ms-iam: condition: service_healthy`.

## 2. Alcance del microservicio

`ms_iam` cubre exclusivamente la responsabilidad de negocio de **identidad, autenticación y administración de usuarios** del dominio MSPI. Concretamente:

- **Autenticación de usuarios** contra Keycloak (Resource Owner Password Credentials — ROPC) y emisión de JWT.
- **Cambio de contraseña** (flujo de primer acceso con contraseña temporal, y cambio voluntario).
- **Segundo factor de autenticación (2FA/TOTP)** opcional, autogestionado por el usuario autenticado.
- **Gestión administrativa de usuarios** (alta, edición, activación/inactivación, restablecimiento de contraseña, listado paginado con búsqueda y filtros) restringida al rol `AdminSistema`.
- **Catálogo de roles** del *realm* de Keycloak, expuesto con etiquetas en español para consumo de los frontends.
- **Bitácora de auditoría centralizada** (`iam.audit_log`): registra tanto los propios eventos de autenticación (`AUTH_LOGIN_SUCCESS`, `AUTH_LOGIN_FAILED`, `AUTH_LOGIN_INACTIVE`) como eventos de negocio que otros microservicios (p. ej. `ms_assessment`) envían vía `POST /internal/audit/events` protegido con una API key interna compartida.
- **Integración saliente con `ms_org`**: al crear un usuario con rol `Lector`, `ms_iam` valida contra `ms_org` (`GET /organizations/{id}`) que la organización exista.
- **Notificaciones por correo** (Brevo) al crear usuarios o restablecer contraseñas.

Quedan **fuera de alcance** de `ms_iam` (y son responsabilidad de otros microservicios del sistema): la gestión de organizaciones (`ms_org`), catálogos de instrumentos/controles (`ms_catalog`), evidencias (`ms_evidence`), evaluaciones (`ms_assessment`) y consolidación de auditoría transversal (`ms_audit`). `ms_iam` únicamente persiste y expone su propia tabla `iam.audit_log`, que además sirve como sumidero (*sink*) de auditoría para otros servicios.

## 3. Objetivos

1. Centralizar la autenticación de todos los actores del sistema MSPI en un único punto de verdad (Keycloak) delegando la gestión de credenciales fuera del propio microservicio.
2. Proveer un control de acceso basado en roles (RBAC) reutilizable por el resto de microservicios mediante JWT firmado y verificable (`realm_access.roles`).
3. Ofrecer una API de administración de usuarios consistente para los administradores del sistema (`AdminSistema`), incluyendo altas con contraseña temporal y bajas/inactivación coordinadas con Keycloak.
4. Ofrecer 2FA opcional (TOTP) como control de seguridad adicional, alineado con los lineamientos de la línea base de seguridad ISO 27001 del proyecto (`docs/linea_base_seguridad_ISO27001.md`).
5. Centralizar la trazabilidad (auditoría) de eventos de identidad y de negocio de otros microservicios en una tabla única e indexada por actor, entidad y tipo de evento.
6. Mantener el microservicio desacoplado de infraestructura mediante arquitectura hexagonal, de forma que el dominio (`domain/model`, `domain/usecase`) no dependa de Spring, JPA ni de ningún detalle de Keycloak.

## 4. Requerimientos iniciales

A partir del código y la documentación (`docs/README.md`, `docs/openapi.yaml`) se identifican los siguientes requerimientos que dieron forma al microservicio:

- **RI-1** — Autenticación centralizada vía Keycloak (no se gestionan contraseñas propias en `ms_iam`; el hash de credenciales vive en el IdP).
- **RI-2** — Cada usuario de MSPI debe tener un perfil espejo en `iam.user` (tabla local), vinculado por `keycloak_sub`, para poder relacionar auditoría, organización y estado sin depender de llamadas constantes a Keycloak.
- **RI-3** — Los roles de negocio (`AdminSistema`, `AdminInstrumento`, `Evaluador`, `Revisor`, `Lector`) deben ser consultables como catálogo y deben mapear a *realm roles* de Keycloak.
- **RI-4** — El primer acceso de un usuario creado por un administrador debe forzar cambio de contraseña (`must_change_password`).
- **RI-5** — Los usuarios con rol `Lector` deben estar asociados a una organización existente en `ms_org`.
- **RI-6** — Debe existir un canal de auditoría interno, protegido por clave compartida, para que otros microservicios (p. ej. `ms_assessment`) registren eventos de negocio en la misma bitácora que usa `ms_iam` para sus propios eventos de login.
- **RI-7** — El servicio debe exponer *health checks* (`/actuator/health`, `/actuator/info`) para que Docker Compose y el orquestador puedan condicionar el arranque de los demás microservicios (`condition: service_healthy`).
- **RI-8** — El microservicio **no debe** ejecutar DDL automáticamente (`spring.sql.init.mode: never`, `hibernate.ddl-auto: none`); el esquema de base de datos se gestiona por scripts SQL versionados y aplicados por el equipo de datos/DevOps.

## 5. Stack tecnológico (versiones reales verificadas en el código)

| Componente | Versión / detalle | Evidencia |
|---|---|---|
| Lenguaje | Java 21 (toolchain) | `main.gradle`: `JavaLanguageVersion.of(21)` |
| Framework | Spring Boot **4.0.2** | `build.gradle`: `springBootVersion = '4.0.2'` |
| Gestor de build | Gradle **9.3.0** (wrapper) | `main.gradle`: `tasks.named('wrapper') { gradleVersion = '9.3.0' }` |
| Modelo web | Spring MVC (servlet, no reactivo) | dependencia `spring-boot-starter-webmvc` en `api-rest/build.gradle`, `app-service/build.gradle` |
| Seguridad | Spring Security + OAuth2 Resource Server (JWT) | `spring-security-oauth2-resource-server`, `spring-security-oauth2-jose` |
| Persistencia | Spring Data JPA + Hibernate | `spring-boot-starter-data-jpa` en `jpa-repository/build.gradle` |
| Base de datos desarrollo | H2 en memoria | `application.yaml`: `jdbc:h2:mem:iam` |
| Base de datos producción | PostgreSQL | `runtimeOnly 'org.postgresql:postgresql'` en `app-service/build.gradle` |
| Gestión de secretos | Infisical SDK 3.0.2 | `com.infisical:sdk:3.0.2` |
| Secrets alternos | AWS Secrets Manager Sync (Bancolombia) 4.4.33 | `com.github.bancolombia:aws-secrets-manager-sync:4.4.33` |
| Resiliencia | Resilience4j Spring Boot 3, versión 2.3.0 | `rest-consumer/build.gradle` |
| Observabilidad | Micrometer + Prometheus registry | `micrometer-registry-prometheus` en `api-rest/build.gradle` |
| TOTP (2FA) | java-otp 0.4.0 + commons-codec 1.16.0 | `jpa-repository/build.gradle` |
| Envío de correo | Cliente propio para API de Brevo (Sendinblue) | módulo `infrastructure/driven-adapters/brevo-sender` |
| Serialización | Jackson (`tools.jackson.core:jackson-databind` y `com.fasterxml.jackson.core:jackson-databind`) | varios `build.gradle` |
| Lombok | 1.18.42 | `build.gradle` raíz |
| Pruebas | JUnit 5 (`useJUnitPlatform()`), Mockito (vía `spring-boot-starter-test`), MockWebServer 5.3.2, ArchUnit 1.4.1, Spring Security Test | ver detalle en `05-Pruebas.md` |
| Cobertura / calidad | JaCoCo 0.8.14, Pitest (mutation testing) 1.19.0-rc.3 / 1.22.0, SonarQube plugin 7.2.2.6593 | `build.gradle`, `main.gradle` |
| Contenedor | `eclipse-temurin:21-jdk-alpine` (build) → `eclipse-temurin:21-jre-alpine` (runtime) | `deployment/Dockerfile` |
| CI/CD | Bitbucket Pipelines, despliegue a Railway | `bitbucket-pipelines.yml` |

## 6. Estructura del proyecto (multi-módulo Gradle)

`settings.gradle` define 8 módulos siguiendo arquitectura hexagonal (Clean Architecture, sin el plugin `co.com.bancolombia.cleanArchitecture` que aparece comentado en `build.gradle`, es decir, la estructura hexagonal se aplica manualmente vía convención de carpetas):

```
MsIam (rootProject)
├── domain/model        → :model      (entidades, VOs, puertos/gateways — sin dependencias de framework)
├── domain/usecase       → :usecase    (casos de uso — solo depende de :model)
├── infrastructure/helpers/common → :common (DTOs de respuesta, excepciones de dominio compartidas)
├── infrastructure/driven-adapters/jpa-repository → :jpa-repository (adaptador de persistencia JPA/H2/PostgreSQL)
├── infrastructure/driven-adapters/rest-consumer  → :rest-consumer  (clientes REST hacia Keycloak y ms_org)
├── infrastructure/driven-adapters/service        → :service       (orquestación de casos de uso complejos: login, cambio de contraseña, gestión de usuarios)
├── infrastructure/driven-adapters/brevo-sender    → :brevo-sender  (adaptador de envío de correo vía Brevo)
├── infrastructure/entry-points/api-rest → :api-rest (controladores REST, seguridad, DTOs, manejo de excepciones)
└── applications/app-service → :app-service (módulo ejecutable Spring Boot, `MainApplication`, configuración de wiring)
```

## 7. Recursos y planificación del desarrollo

No se encontró en el repositorio de `ms_iam` un archivo `ROADMAP.md`, `CHANGELOG.md` ni un plan de iteraciones específico del microservicio (a diferencia de, por ejemplo, `ms_admin/docs/ROADMAP.md` o `ms_audit/docs/MIGRATION-NOTES.md`, que sí existen para otros microservicios del mismo repositorio contenedor). La planificación general del proyecto de grado se documenta a nivel de todo el sistema MSPI en:

- `docs/proyecto/PLAN_TRABAJO_MSPI_v2.md` — plan de trabajo global del proyecto.
- `docs/proyecto/Historias_Usuario_MSPI_v2.md` — historias de usuario del sistema completo (de las cuales varias corresponden a los flujos de acceso, gestión de usuarios y 2FA implementados aquí).
- `docs/proyecto/DB-MER.txt` y `docs/proyecto/MER.drawio` — modelo entidad-relación de referencia para todos los esquemas, incluido `iam`.
- `docs/linea_base_seguridad_ISO27001.md` — línea base de controles de seguridad ISO/IEC 27001 que fundamentan requisitos como el cambio obligatorio de contraseña, el 2FA y la auditoría centralizada.

Dado que no existe evidencia de un cronograma o backlog propio de `ms_iam`, este documento declara explícitamente esa ausencia en lugar de inventar fechas o hitos. La comparación entre el modelo de datos y las hojas de cálculo del proyecto (`docs/proyecto/DBvsExcel.md`) sugiere que la planificación detallada se llevó a nivel de todo el sistema y no por microservicio individual.

## 8. Actores interesados (stakeholders) inferidos del dominio

| Actor | Interés en `ms_iam` |
|---|---|
| `AdminSistema` (administrador del sistema MSPI) | Consumidor directo de `/users/**`, gestiona altas, bajas y restablecimientos de contraseña |
| Usuarios finales (`Evaluador`, `Revisor`, `Lector`, `AdminInstrumento`) | Consumidores de `/auth/login`, `/auth/change-password`, `/auth/totp/*` |
| `ms_org` | Consumidor de `POST /users` y `POST /users/disable-by-email`; proveedor de `GET /organizations/{id}` consultado por `ms_iam` |
| `ms_assessment` (y otros microservicios) | Consumidores de `POST /internal/audit/events` mediante `INTERNAL_API_KEY` compartida |
| Equipo DevOps / DBA | Responsables de aplicar `schema-iam-mvp.sql` / `schema-iam-patch.sql`, dado que el microservicio no ejecuta DDL |
| Keycloak (IdP) | Proveedor de identidad; `ms_iam` actúa como *Resource Server* y como cliente administrativo (*service account* `mspi-backend`) |
