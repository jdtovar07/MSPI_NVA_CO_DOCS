# ms_iam — Mantenimiento

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_iam` |
| Fecha del documento | 2026-08-18 |
| Alcance | Lineamientos de mantenimiento correctivo, preventivo y evolutivo del microservicio `ms_iam`, basados en lo observado en el código, la configuración y la documentación del repositorio |

---

## 1. Gestión de versiones

No se encontró en `ms_iam/` un archivo `CHANGELOG.md` ni convención de *commits* documentada (sin `CONTRIBUTING.md` ni configuración de *commitlint*/`husky` en el repositorio). La única referencia de versión explícita en el código es:

- `docs/openapi.yaml` → `info.version: 2.0.0` (versión del contrato de API).
- `docs/openapi.yaml` → ejemplo de `GET /actuator/info` que muestra `app.version: 2.0.0` y `build.version: 2.0.0`, sugiriendo que la versión de la aplicación se sincroniza (al menos como convención de ejemplo) con la del contrato OpenAPI.

**Recomendación**: dado que no existe versionamiento semántico formalizado ni `CHANGELOG.md`, se recomienda introducir uno (siguiendo *Keep a Changelog* + SemVer) y sincronizarlo con `info.version` de `docs/openapi.yaml`, especialmente porque `ms_iam` es consumido por al menos dos microservicios (`ms_org`, `ms_assessment`) que dependen de la estabilidad de su contrato.

## 2. Mantenimiento correctivo

### 2.1 Manejo de errores existente

El microservicio centraliza el manejo de errores en `GlobalExceptionHandler` (`@RestControllerAdvice`), con **10 manejadores de excepción específicos** más un manejador genérico (`Exception.class`) como red de seguridad final. Puntos clave para diagnóstico correctivo:

- Todo error incluye `traceId` (propagado o generado vía `MDC`/`TraceIdFilter`), lo que permite correlacionar un error reportado por un usuario con las líneas de log correspondientes (`log4j2.properties` / `logback.xml` incluyen `traceId=%X{traceId}` en el patrón de salida).
- Los errores de Keycloak u otros servicios REST (`RestClientResponseException`) se propagan con el mismo código HTTP recibido y el cuerpo de respuesta (truncado a 500 caracteres), salvo el caso especial de **403 desde Keycloak Admin API**, para el cual el sistema **ya incluye un mensaje de diagnóstico accionable** apuntando al script `docker-config/docker/keycloak/scripts/setup-keycloak.ps1` — este patrón (mensajes de error auto-explicativos con el remedio) debería replicarse para otros errores recurrentes conocidos del equipo.
- El error más documentado en `docs/README.md` (`relation "iam.audit_log" does not exist` al hacer login) es un problema **operativo, no de código**: falta de aplicación del DDL. El manual ya lo documenta con el remedio (`schema-iam-patch.sql` / `apply-all-schemas.ps1`). Se recomienda mantener esta sección del README actualizada cada vez que se agregue una tabla nueva al esquema `iam`.

### 2.2 Puntos de fragilidad identificados (a vigilar en mantenimiento correctivo)

- **`iam.system_config`** existe en el DDL pero no se encontró código de aplicación que la consuma; si en el futuro se implementa, debe revisarse que el mantenimiento del esquema (`schema-iam-mvp.sql`/`schema-iam-patch.sql`) y el código evolucionen en conjunto.
- **`UserQueryGatewayAdapter`** vive en `applications/app-service` en lugar de en `infrastructure/driven-adapters/jpa-repository`, rompiendo la simetría del resto de adaptadores de persistencia. Cualquier refactor de la capa de persistencia debe tener presente esta excepción a la regla de ubicación de adaptadores.
- **`EmailGateway` opcional** (`@Autowired(required = false)`): si Brevo falla silenciosamente en la configuración (bean no creado), la creación de usuarios **no notifica al usuario su contraseña temporal** sin que se genere ningún error visible — un `AdminSistema` debería comunicar manualmente la contraseña en ese escenario. Vale la pena instrumentar una alerta/log de advertencia explícito cuando `emailGateway == null` en tiempo de ejecución.
- **Ausencia de invalidación/expiración de secretos TOTP no verificados**: `TotpSetupUseCase` genera y persiste el secreto inmediatamente (`TotpAdapter.saveSecret`), incluso antes de que el usuario lo verifique (`TotpVerifyUseCase`/`enabled_at` nulo). Si un usuario invoca `setup` repetidamente sin verificar, cada llamada sobrescribe el secreto anterior (comportamiento correcto), pero no hay una política de expiración visible para secretos "pendientes de verificar" indefinidamente.

## 3. Mantenimiento preventivo

### 3.1 Observabilidad y logging

- **Logging estructurado por prefijo de componente**: convención consistente en todo el código (`[API][auth]`, `[API][users]`, `[ADAPTER][LoginService]`, `[ADAPTER][KeycloakAuth]`, `[API][exception]`), lo que facilita filtrar logs por capa/componente en herramientas de observabilidad centralizada.
- **`logback.xml`** define un único *appender* de consola con patrón `[%-5level] %d{yyyy-MM-dd HH:mm:ss.SSS} [%thread] [%logger{36}] traceId=%X{traceId} | %msg%n`, nivel raíz `INFO`. También existe `log4j2.properties` en el mismo classpath — **presencia simultánea de dos frameworks de logging configurados** (Logback, el estándar de Spring Boot, y Log4j2) es una redundancia a revisar; se recomienda auditar cuál está realmente activo (Spring Boot usa Logback por defecto salvo exclusión explícita) y eliminar el archivo de configuración no utilizado para evitar confusión en mantenimiento futuro.
- **Métricas Prometheus** ya expuestas vía Actuator + Micrometer (`micrometer-registry-prometheus`), listas para conectar a un stack de monitoreo (Prometheus/Grafana), aunque no se encontró evidencia de dashboards o alertas ya definidas en el repositorio.
- **Healthcheck de Docker** (`/actuator/health`, cada 30s) es la única señal de disponibilidad activa hoy; se recomienda como mejora preventiva añadir *health indicators* personalizados para dependencias críticas (conexión a Keycloak, disponibilidad de `ms_org`) para que `/actuator/health` refleje también la salud de integraciones externas, no solo la de la aplicación y la base de datos.

### 3.2 Gestión de calidad de código (ya configurada, pendiente de activar en CI)

Como se documenta en `05-Pruebas.md`, el proyecto **ya tiene** JaCoCo (umbral 80%), Pitest (mutation testing) y SonarQube configurados a nivel de Gradle, pero el pipeline de CI (`bitbucket-pipelines.yml`) no los ejecuta. Como acción preventiva prioritaria de mantenimiento:

1. Incorporar `./gradlew check` al pipeline `dev` antes del `assemble`/deploy.
2. Programar ejecución periódica (o en cada PR, si se habilita ese trigger) de análisis SonarQube para detectar regresiones de calidad y *code smells* de forma temprana.
3. Revisar periódicamente el reporte de Pitest para verificar que la suite de pruebas realmente detecta mutaciones (cobertura de líneas ≠ cobertura de mutaciones; el proyecto ya tiene la infraestructura para medir ambas).

### 3.3 Gestión de dependencias

- Varias dependencias usan versiones de **release candidate o muy recientes** (`pitestVersion = '1.19.0-rc.3'` como versión de plugin, Spring Boot `4.0.2`, Gradle `9.3.0`), lo que implica mayor riesgo de breaking changes en actualizaciones y requiere seguimiento activo de *release notes* antes de actualizar versiones mayores.
- El comentario `// TODO: remove this to use real database` sobre `runtimeOnly 'com.h2database:h2'` en `jpa-repository/build.gradle` es una nota de deuda técnica dejada explícitamente por el equipo de desarrollo — debe evaluarse si H2 debe moverse a `testRuntimeOnly` en vez de `runtimeOnly` general, para evitar que quede disponible como *fallback* silencioso en producción si `DB_CREDENTIAL` no se configura correctamente (hoy, si la variable falta, el servicio arranca "exitosamente" contra una base de datos en memoria vacía en lugar de fallar de forma explícita).

## 4. Mantenimiento evolutivo

No existe un `ROADMAP.md` propio de `ms_iam` (a diferencia de otros microservicios del mismo repositorio contenedor, como `ms_admin/docs/ROADMAP.md`), por lo que no se puede documentar aquí un backlog oficial sin inventarlo. A partir de las brechas funcionales identificadas en el análisis del código (`02-Analisis.md` §6) y de las ausencias técnicas señaladas en este documento, se listan **posibles líneas de evolución** fundamentadas en el propio código, no en supuestos externos:

1. **Recuperación de contraseña autoservicio** ("forgot password" sin intervención de `AdminSistema"), dado que hoy `POST /auth/change-password` exige conocer la contraseña actual.
2. **Deshabilitación/reset de TOTP** por parte de un administrador (para usuarios que pierden su dispositivo), ya que solo existen `setup`, `verify` y `status`.
3. **Formalización de pruebas de arquitectura con ArchUnit**, aprovechando que la dependencia ya está declarada (`archunit:1.4.1` en `app-service`) pero no tiene pruebas asociadas.
4. **Activación de `system_config`** si el caso de uso de configuración paramétrica (mencionado en el DDL pero no implementado en código) sigue vigente en el alcance del proyecto.
5. **Migración de H2 fuera del `runtimeOnly`** general del módulo de persistencia, formalizando el fallback de desarrollo como perfil explícito (`spring.profiles.active=local`) en lugar de comportamiento implícito por ausencia de `DB_CREDENTIAL`.
6. **Incorporación de pruebas de integración con Testcontainers** contra PostgreSQL real, para complementar las actuales pruebas unitarias con mocks en `jpa-repository`.
7. **Activación de la etapa de calidad (`check`/Sonar) en el pipeline de CI**, siguiendo la configuración ya presente en Gradle.

## 5. Notas de migración

No se encontró un archivo `MIGRATION-NOTES.md` en `ms_iam/` (a diferencia de `ms_audit/docs/MIGRATION-NOTES.md` en el mismo repositorio contenedor). Las únicas "notas de migración" reales presentes en el código son los propios scripts SQL:

- `schema-iam-mvp.sql` — script de creación completa para una base de datos nueva.
- `schema-iam-patch.sql` — script **idempotente** (`CREATE TABLE IF NOT EXISTS`, bloques `DO $$ ... EXCEPTION WHEN undefined_table THEN NULL ... END $$`) diseñado explícitamente para aplicar sobre bases de datos `iam` ya existentes sin recrear el volumen Docker, cubriendo el caso de que `audit_log`, `system_config` o `user_totp` falten en un entorno que fue provisionado antes de que esas tablas se agregaran al MER. Este patrón de *migración aditiva y segura* es el mecanismo real de evolución de esquema del microservicio y debería mantenerse como estándar para cualquier cambio futuro de modelo de datos (evitar `DROP`/`ALTER` destructivos directos; preferir scripts aditivos e idempotentes).

## 6. Resumen de responsabilidades de mantenimiento por rol

| Rol | Responsabilidad de mantenimiento |
|---|---|
| Equipo de desarrollo backend | Evolución de casos de uso, mantenimiento de cobertura ≥80%, actualización de `docs/openapi.yaml` ante cualquier cambio de contrato |
| DBA / DevOps | Aplicación de scripts SQL (`schema-iam-mvp.sql`/`schema-iam-patch.sql`) en cada entorno, dado que el microservicio no ejecuta DDL |
| Equipo de seguridad | Rotación de `INTERNAL_API_KEY`, `KEYCLOAK_CLIENT_SECRET`, revisión periódica de roles `realm-management` asignados al *service account* `mspi-backend`, alineado con `docs/linea_base_seguridad_ISO27001.md` |
| Equipo de infraestructura | Mantenimiento del pipeline (`bitbucket-pipelines.yml`), gestión de despliegue en Railway, actualización de imágenes base (`eclipse-temurin:21-*-alpine`) ante CVEs |
