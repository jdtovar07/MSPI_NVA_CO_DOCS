# ms_org — Mantenimiento

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_org` |
| Fecha del documento | 2026-08-19 |
| Alcance | Lineamientos de mantenimiento correctivo, preventivo y evolutivo del microservicio `ms_org`, basados en lo observado en el código, la configuración y la documentación del repositorio |

---

## 1. Gestión de versiones

No se encontró en `ms_org/` un archivo `CHANGELOG.md` ni convención de *commits* documentada. La única referencia de versión explícita en el código es `docs/openapi.yaml` → `info.version: 1.0.0`. El historial de `git log` del repositorio contenedor muestra únicamente 3 commits raíz relevantes para `ms_org` (creación inicial, migración al monorepo, incorporación de `docker-config`), sin evidencia de iteraciones versionadas del propio microservicio.

**Recomendación**: introducir versionamiento semántico (SemVer) sincronizado con `info.version` de `docs/openapi.yaml`, especialmente relevante porque `ms_org` es consumido tanto por `ms_iam` (`GET /organizations/{id}`) como, previsiblemente, por `ms_assessment`/`ms_evidence`/`ms_reporting`, cuya estabilidad de contrato depende de este servicio.

## 2. Mantenimiento correctivo

### 2.1 Manejo de errores existente

`GlobalExceptionHandler` centraliza 6 manejadores de excepción específicos. Cada error incluye `traceId` (propagado o generado vía `MDC`/`TraceIdFilter`), permitiendo correlacionar un error reportado por un usuario con las líneas de log correspondientes. Los errores de `ms_iam` (`RestClientResponseException`) se traducen explícitamente distinguiendo el caso `DUPLICATE_EMAIL` (409) del resto (502), con mensaje truncado a 300 caracteres si el cuerpo de error no es JSON parseable — patrón de traducción de errores externos ya validado en `ms_iam` respecto a Keycloak.

### 2.2 Puntos de fragilidad identificados (a vigilar en mantenimiento correctivo)

- **Compensación no atómica en `CreateOrganizationGatewayAdapter`**: la reversión ante fallo de `ms_iam` ejecuta `rollbackOrganizationCreation` en una transacción `REQUIRES_NEW` independiente de las transacciones que guardaron la organización y el contacto. Si el proceso se interrumpe (caída del pod, *timeout* de red) exactamente entre la llamada a `ms_iam` y la ejecución del rollback, puede quedar una organización con contacto persistido pero **sin** usuario `Lector` en `ms_iam`, y sin ningún mecanismo de reconciliación automática. Se recomienda instrumentar una alerta operativa o un job de reconciliación periódico que detecte organizaciones sin usuario `Lector` asociado.
- **Sin cobertura de prueba en la ruta más sensible**: como se documenta en `05-Pruebas.md`, `OrganizationJpaAdapter`, `CreateOrganizationGatewayAdapter`, `IamGatewayAdapter` y `LocationCatalogAdapter` no tienen pruebas automatizadas, por lo que cualquier regresión en la lógica de unicidad, compensación o traducción de errores solo se detectaría manualmente o en producción.
- **`pw.toString()` sin efecto en `IamGatewayAdapter.createLectorUser`**: la contraseña temporal devuelta por `ms_iam` se lee del `Map` de respuesta pero no se usa ni se registra en log de forma explícita — código muerto o incompleto que debería limpiarse o completarse (p. ej. con un log `[ADAPTER][IamGateway] lector user created (password sent by ms_iam)` sin exponer la contraseña).
- **`status` y `type` de `Organization` son `String` libres**, sin `enum` ni validación de valores permitidos ni en el DTO (`OrganizationRequest`) ni en el modelo de dominio — un valor arbitrario en `status` (p. ej. `"activo"` en vez de `"ACTIVE"`) sería aceptado silenciosamente y podría romper filtros o integraciones que asuman los valores documentados en el OpenAPI (`ACTIVE`).
- **`disableUserByEmail` absorbe cualquier error de `ms_iam`** sin distinguir "usuario no existe" (caso esperado) de otros errores reales (p. ej. `ms_iam` caído, 500 interno) — ambos casos se registran como `warn` y se ignoran igual, lo que podría ocultar una falla real de sincronización de forma silenciosa en producción.

## 3. Mantenimiento preventivo

### 3.1 Observabilidad y logging

- **Logging estructurado por prefijo de componente**, consistente con `ms_iam`: `[ADAPTER][OrganizationJpa]`, `[ADAPTER][CreateOrganization]`, `[ADAPTER][IamGateway]`, `[FILTER][traceId]`, facilitando el filtrado por capa/componente en herramientas de observabilidad centralizada.
- **Sin métricas Prometheus explícitas**: a diferencia de `ms_iam` (que declara `micrometer-registry-prometheus`), `ms_org` **no incluye esa dependencia** en ningún `build.gradle` revisado — solo tiene `spring-boot-starter-actuator` (habilita `/actuator/health` e `/actuator/info`, pero no expone `/actuator/prometheus` por defecto sin el registro adecuado). Se recomienda añadir `micrometer-registry-prometheus` a `api-rest/build.gradle` si se desea alinear la observabilidad con el resto del sistema MSPI.
- **Healthcheck de Docker** (`/actuator/health`, cada 30s) es la única señal de disponibilidad activa; se recomienda añadir *health indicators* personalizados para las dos integraciones críticas (`ms_iam` y la API de ubicación), de forma que `/actuator/health` refleje también su disponibilidad y no solo la de la base de datos.
- **Sin *circuit breaker*** en las llamadas salientes a `ms_iam` ni a Country State City (no hay Resilience4j en este microservicio, a diferencia de `ms_iam`). La API de ubicación ya degrada con gracia (lista vacía) en el propio código de la aplicación, pero la llamada a `ms_iam` en la creación de organización no tiene *timeout* explícito configurado en `IamRestClientConfig` (usa la configuración por defecto de `RestClient`), lo que podría dejar una petición de creación de organización colgada más tiempo del deseable si `ms_iam` no responde.

### 3.2 Gestión de calidad de código (ya configurada, pendiente de activar en CI)

Como se documenta en `05-Pruebas.md`, el proyecto **ya tiene** JaCoCo (umbral 80%), Pitest (mutation testing) y SonarQube configurados a nivel de Gradle (heredado de la configuración raíz compartida con `ms_iam`), pero el pipeline de CI (`bitbucket-pipelines.yml`) no los ejecuta. Acciones preventivas prioritarias:

1. Escribir las pruebas faltantes de `OrganizationJpaAdapter` y `CreateOrganizationGatewayAdapter` (ver `05-Pruebas.md` §5) antes de activar `check` en el pipeline, para evitar que el umbral del 80% bloquee despliegues sin dar tiempo a cerrar la brecha.
2. Incorporar `./gradlew check` al pipeline `dev` antes del `assemble`/deploy.
3. Conectar la publicación de `build/reports/**` (ya generados y declarados como artefacto en el `step` `Build App`) hacia SonarQube en un paso dedicado.

### 3.3 Gestión de dependencias

- Spring Boot `4.0.2` y Gradle `9.3.0` son versiones recientes/mayores; requieren seguimiento activo de *release notes* antes de actualizar versiones mayores adicionales.
- `com.infisical:sdk:3.0.2` y `com.tngtech.archunit:archunit:1.4.1` son las únicas dependencias de terceros con versión fijada explícitamente fuera del BOM de Spring Boot; conviene revisarlas periódicamente por CVEs conocidos, dado que Infisical maneja secretos sensibles (`DB_CREDENTIAL`, credenciales del microservicio).
- No se encontró en `ms_org` un mecanismo de actualización automática de dependencias (Dependabot/Renovate) configurado en el repositorio.

## 4. Mantenimiento evolutivo

No existe un `ROADMAP.md` propio de `ms_org`. A partir de las brechas funcionales identificadas en `02-Analisis.md` §7 y de las observaciones técnicas de este documento, se listan posibles líneas de evolución fundamentadas en el propio código:

1. **Endpoint de eliminación o desactivación explícita de organizaciones** (`DELETE` o `PATCH /organizations/{id}/status`), dado que hoy el ciclo de vida solo contempla creación, consulta y actualización completa.
2. **Validación cerrada de `status` y `type`** mediante `enum` en el dominio y `@Pattern`/`@ValueOfEnum` en el DTO, para evitar valores inconsistentes en base de datos.
3. **Gestión de contactos adicionales** más allá del contacto principal, aprovechando que `org.organization_contact` ya soporta múltiples registros por organización (`organization_id`, `is_primary`) pero la API solo expone el contacto principal.
4. **Caché del catálogo geográfico** (Spring Cache / Caffeine) para `LocationCatalogAdapter`, dado que los datos de países/estados/ciudades cambian con muy baja frecuencia y hoy cada consulta dispara una llamada HTTP saliente nueva a un proveedor externo de terceros.
5. **Job de reconciliación** para detectar organizaciones sin usuario `Lector` asociado (ver §2.2), formalizando la compensación manual actual con un mecanismo de verificación periódica.
6. **Incorporación de Resilience4j** (ya usado en `ms_iam`) para las llamadas salientes a `ms_iam` y a la API de ubicación, con *timeout*, *retry* y *circuit breaker* explícitos en vez de depender solo de manejo de excepciones *ad hoc*.
7. **Formalización de pruebas de arquitectura con ArchUnit**, aprovechando que la dependencia ya está declarada (`archunit:1.4.1` en `app-service`) pero no tiene pruebas asociadas — misma brecha detectada en `ms_iam`.
8. **Cobertura de prueba de los adaptadores de infraestructura críticos** (`OrganizationJpaAdapter`, `CreateOrganizationGatewayAdapter`, `IamGatewayAdapter`, `LocationCatalogAdapter`), priorizada sobre cualquier otra mejora evolutiva por ser la brecha de calidad más relevante detectada en el análisis (`05-Pruebas.md`).

## 5. Notas de migración

No se encontró un archivo `MIGRATION-NOTES.md` en `ms_org/`. Las únicas referencias de esquema de base de datos presentes son:

- `applications/app-service/src/main/resources/schema.sql` — script de referencia (`org.organization`, `org.organization_contact`), con comentario propio que indica que está pensado para desarrollo local, aunque el módulo `jpa-repository` no incluye driver H2 y `spring.sql.init.mode: never` impide su ejecución automática incluso en local (ver `06-Implementacion-Despliegue.md` §6).
- `docs/MVP-MSPI-CONTRATOS-Y-MER.md` §6.1 — DDL de referencia para PostgreSQL, alineado con el DBML del MER general de MSPI, incluyendo los índices de unicidad y búsqueda (`idx_org_name_identifier_unique`, `idx_org_name`, `idx_org_identifier`).

A diferencia de `ms_iam` (que mantiene `schema-iam-mvp.sql` y `schema-iam-patch.sql` como par completo/idempotente), `ms_org` **no tiene un script "patch" idempotente propio** en el repositorio revisado; cualquier cambio de esquema futuro debería adoptar el mismo patrón de migración aditiva y segura (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` donde el motor lo soporte) ya validado en `ms_iam`, para mantener consistencia de estrategia de migración entre los microservicios del sistema MSPI.

## 6. Resumen de responsabilidades de mantenimiento por rol

| Rol | Responsabilidad de mantenimiento |
|---|---|
| Equipo de desarrollo backend | Evolución de casos de uso, cierre de la brecha de cobertura de pruebas en `jpa-repository` y `app-service`, actualización de `docs/openapi.yaml` ante cualquier cambio de contrato |
| DBA / DevOps | Aplicación del DDL del esquema `org` en cada entorno (`docs/MVP-MSPI-CONTRATOS-Y-MER.md` §6.1), dado que el microservicio no ejecuta DDL ni tiene fallback a H2 |
| Equipo de seguridad | Rotación de credenciales Infisical, revisión periódica de la API key de Country State City (`LOCATION_API_KEY`) y del alcance de los tokens JWT aceptados |
| Equipo de infraestructura | Mantenimiento del pipeline (`bitbucket-pipelines.yml`), gestión de despliegue en Railway, actualización de imágenes base (`eclipse-temurin:21-*-alpine`) ante CVEs |
| Equipo responsable de `ms_iam` | Mantener estable el contrato de `POST /users` y `POST /users/disable-by-email` consumido por `ms_org`, dado el acoplamiento fuerte entre ambos microservicios en el flujo de creación/actualización de organización |
