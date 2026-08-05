# ms_assessment — Mantenimiento

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_assessment` |
| Fecha del documento | 2026-08-19 |
| Alcance | Lineamientos de mantenimiento correctivo, preventivo y evolutivo del microservicio `ms_assessment`, basados en lo observado en el código, la configuración y la documentación del repositorio |

---

## 1. Gestión de versiones

No se encontró `CHANGELOG.md`, `CONTRIBUTING.md` ni convención de *commits* formalizada en `ms_assessment/`. La única referencia de versión explícita es:

- `docs/openapi.yaml` → `info.version: 1.0.0` (el contrato de `ms_iam` está en `2.0.0`, lo que sugiere ciclos de evolución independientes por microservicio dentro del mismo monorepo contenedor).

**Recomendación**: introducir versionamiento semántico (SemVer + *Keep a Changelog*) sincronizado con `info.version` de `docs/openapi.yaml`, con especial cuidado porque `ms_assessment` es consumido tanto por el frontend (API pública `/assessments/**`) como por `ms_reporting` (API interna `/internal/assessments/**`): cualquier cambio incompatible en `ReportExportBundleResponse` o en `GapListResponse` rompe silenciosamente a `ms_reporting` si no hay control de versión de contrato.

## 2. Mantenimiento correctivo

### 2.1 Manejo de errores existente

`GlobalExceptionHandler` centraliza 6 manejadores específicos (`ResourceNotFoundException`→404, `BusinessRulesOnFieldsException`→400, `UserAlreadyExistsException`→409, `IamServiceException`→502, `MethodArgumentNotValidException`→400, `DomainException`→500). A diferencia de `ms_iam`, **no existe un manejador genérico `Exception.class`** como red de seguridad final (ver `03-Diseno.md` §7). Puntos clave para diagnóstico correctivo:

- Todo error mapeado incluye `traceId` (MDC/`TraceIdFilter`), permitiendo correlacionar un error reportado con las líneas de log correspondientes.
- **Riesgo real identificado**: cualquier excepción no contemplada explícitamente (p. ej. una `NullPointerException` en un cálculo de rollup con datos de catálogo inconsistentes, o una `RestClientException` no envuelta al llamar a `ms_catalog`/`ms_org`/`ms_evidence`) se propaga como el manejador de error genérico por defecto de Spring Boot (`/error`), **sin el envoltorio `ErrorResponse{meta,error[]}`** que el resto del contrato promete — rompiendo la consistencia de formato de respuesta documentada en `README.md` ("Formato de respuestas"). Se recomienda añadir un `@ExceptionHandler(Exception.class)` de cierre, siguiendo el patrón ya existente en `ms_iam`.
- `CurrentUserResolver` ya incluye un mensaje de error operativo accionable ("Usuario no registrado en iam.user. Ejecuta seed-usuario-principal.ps1 o crea el usuario en ms_iam.") — este patrón de mensajes auto-explicativos debería extenderse a otros puntos de integración fallida (p. ej. cuando `ms_catalog` no tiene una plantilla activa publicada al crear una evaluación).

### 2.2 Puntos de fragilidad identificados (a vigilar en mantenimiento correctivo)

- **`UserAlreadyExistsException` sin punto de lanzamiento**: la excepción y su manejador HTTP 409 están presentes en el código (heredados del módulo `:common` compartido) pero no se encontró ningún caso de uso de `ms_assessment` que la lance. Es código muerto desde la perspectiva funcional de este microservicio; debe evaluarse si eliminarla del manejador local o documentarla como reutilización intencional del contrato compartido.
- **`AssessmentJpaAdapter` como puerto "gordo" sin prueba**: una sola clase implementa los 39 métodos de `AssessmentPersistenceGateway`, incluyendo lógica no trivial de materialización y clonación de snapshots jerárquicos, sin ninguna prueba automatizada (ver `05-Pruebas.md`). Cualquier refactor de este adaptador es de alto riesgo sin regresión automatizada.
- **Ausencia de fallback a base de datos embebida**: a diferencia de `ms_iam` (H2 en memoria si falta `DB_CREDENTIAL`), `ms_assessment` no tiene ningún mecanismo de arranque sin PostgreSQL real. Si esto es intencional (evitar arranques "exitosos" contra datos vacíos, riesgo que el propio equipo de `ms_iam` señaló como deuda técnica en su `TODO`), debería documentarse explícitamente como decisión de diseño en lugar de ser solo una ausencia observable.
- **Discrepancia README vs. configuración real** sobre `spring.sql.init.mode` (README dice `always`, `application.yaml` dice `never` — ver `06-Implementacion-Despliegue.md` §3.1): riesgo de que un desarrollador nuevo asuma que el esquema se crea automáticamente y pierda tiempo diagnosticando errores de "relación no existe" sin saber que debe aplicar `schema.sql` manualmente.
- **`recommendationRuleType` y umbral de recomendación dependientes de `ms_catalog`**: la regla de negocio "recomendación obligatoria solo si `score < umbral` cuando `recommendationRuleType = THRESHOLD`" (ver `02-Analisis.md` §4.2) depende de un valor de configuración remoto (`ControlRuleInfo`); un cambio silencioso en `ms_catalog` de ese umbral altera el comportamiento de validación de `ms_assessment` sin ningún cambio de código local — acoplamiento a vigilar si `ms_catalog` cambia su contrato sin coordinación.

## 3. Mantenimiento preventivo

### 3.1 Observabilidad y logging

- **Trazabilidad por `X-Trace-Id`** (`TraceIdFilter`), propagada a MDC y a los logs de auditoría best-effort hacia `ms_iam` — mismo patrón que `ms_iam`.
- **Auditoría best-effort con captura genérica** (`IamAuditGatewayAdapter`, `catch (Exception ex) { log.warn(...) }`): si `ms_iam` está caído, los eventos `ASSESSMENT_PUBLISHED` y de asignación de tipo de entidad simplemente no se registran, sin reintentos ni cola de eventos pendientes. Para un sistema de gestión de seguridad de la información (ISO 27001) donde la auditoría es un requisito de cumplimiento, esta pérdida silenciosa de eventos es un punto a revisar: se recomienda al menos loguear localmente en un formato reprocesable (o encolar) los eventos de auditoría que fallan, en lugar de solo advertir en log de aplicación.
- **Métricas Prometheus**: no se detectó `micrometer-registry-prometheus` en ningún `build.gradle` de `ms_assessment` (a diferencia de `ms_iam`, que sí lo declara en `api-rest`) — solo Actuator base (`spring-boot-starter-actuator`), lo que limita la observabilidad de métricas de negocio (tiempos de rollup, tasa de fallos de auditoría, etc.) frente a lo ya disponible en `ms_iam`.
- **Healthcheck de Docker** es la única señal de disponibilidad activa; como en `ms_iam`, se recomienda añadir *health indicators* personalizados que reflejen la salud de las 4 integraciones externas (`ms_org`, `ms_catalog`, `ms_evidence`, `ms_iam`), dado que este microservicio es el que más depende de servicios remotos del ecosistema.

### 3.2 Gestión de calidad de código (ya configurada, pendiente de activar en CI)

Igual que en `ms_iam`: JaCoCo (80%), Pitest y SonarQube están configurados en Gradle pero el pipeline (`bitbucket-pipelines.yml`) no los ejecuta. Acciones preventivas prioritarias:

1. Incorporar `./gradlew check` al pipeline `dev` antes de `assemble`/deploy.
2. Dado que la cobertura real está concentrada en `:usecase` (ver `05-Pruebas.md`), verificar con un reporte real de JaCoCo si el 80% agregado se cumple hoy o si el build fallaría al activar el `check` — priorizar cerrar la brecha de `AssessmentJpaAdapter` y `rest-consumer` antes de activar el *gate* obligatorio, para no bloquear despliegues legítimos con una deuda de pruebas preexistente.
3. Publicar los artefactos de `build/reports/**` hacia SonarQube en un paso dedicado del pipeline.

### 3.3 Gestión de dependencias

- Mismas versiones "de vanguardia" que el resto del ecosistema (Spring Boot 4.0.2, Gradle 9.3.0, Pitest `1.19.0-rc.3` como *release candidate*), con el mismo riesgo de *breaking changes* en actualizaciones mayores.
- No se detectó ninguna dependencia de base de datos embebida (`H2`) en ningún `build.gradle`, por lo que no aplica la deuda técnica de `ms_iam` sobre `runtimeOnly` de H2 — pero, como contrapartida, cualquier entorno de desarrollo local requiere PostgreSQL provisionado (ver `06-Implementacion-Despliegue.md` §6.1).
- `com.tngtech.archunit:archunit:1.4.1` y `org.reactivecommons.utils:object-mapper:0.1.0` están declaradas sin uso confirmado en pruebas — candidatas a remover si no se van a formalizar pruebas de arquitectura/mapeo, o a completar con las pruebas correspondientes.

## 4. Mantenimiento evolutivo

No existe un `ROADMAP.md` propio de `ms_assessment`. A partir de las brechas funcionales de `02-Analisis.md` §6 y de las ausencias técnicas señaladas en este documento, se listan posibles líneas de evolución fundamentadas en el propio código:

1. **Workflow de aprobación multiusuario / roles diferenciados**: hoy toda ruta bajo `/assessments/**` solo exige `authenticated()` (más `ROLE_USER` automático); no hay `@PreAuthorize` por rol de negocio (p. ej. "Evaluador" vs. "Revisor"). Si el proceso ISO 27001 requiere separación de funciones (quien calienta no publica), esto debe formalizarse.
2. **Endpoint de eliminación / soft-delete de evaluaciones**: `AssessmentPersistenceGateway` no declara ningún método `delete`; no existe forma de retirar una evaluación creada por error salvo intervención directa en base de datos.
3. **Cierre de la brecha de cobertura de pruebas** en `AssessmentJpaAdapter`, los 5 adaptadores `rest-consumer` y 21 de 28 casos de uso (ver `05-Pruebas.md` §5), priorizando por criticidad de negocio (`CreateAssessmentUseCase`, `PublishAssessmentUseCase`, `CloneAssessmentUseCase`).
4. **Manejador genérico de excepciones** (`Exception.class`) en `GlobalExceptionHandler`, para no romper el contrato uniforme `ErrorResponse` ante errores no anticipados.
5. **Mecanismo de reintento o cola para eventos de auditoría fallidos** hacia `ms_iam`, dado el carácter de cumplimiento normativo del sistema (ISO 27001) y la naturaleza *best-effort* actual sin persistencia local de respaldo.
6. **Métricas Prometheus** (`micrometer-registry-prometheus`), ausentes hoy en `ms_assessment` pero presentes en `ms_iam`, para monitoreo de negocio (latencia de rollup, tasa de fallos de integración externa).
7. **Corrección de la documentación** (`README.md` §Configuración y ejecución) sobre `spring.sql.init.mode`, para reflejar el comportamiento real (`never`) y evitar confusión operativa.
8. **Formalización de pruebas de arquitectura con ArchUnit**, aprovechando la dependencia ya declarada, para verificar automáticamente que `domain/model` y `domain/usecase` no dependan de Spring/JPA/HTTP.
9. **Activación de la etapa de calidad (`check`/Sonar) en el pipeline de CI**, siguiendo la configuración ya presente en Gradle — misma recomendación que para `ms_iam`.

## 5. Notas de migración

No se encontró un archivo `MIGRATION-NOTES.md` en `ms_assessment/`. La única "nota de migración" real es el propio `schema.sql`, que usa consistentemente `CREATE TABLE IF NOT EXISTS`/`CREATE INDEX IF NOT EXISTS` (patrón aditivo e idempotente, igual que `schema-iam-patch.sql` en `ms_iam`), lo que permite reaplicarlo sobre una base de datos ya provisionada sin recrear el volumen completo — aunque, a diferencia de `ms_iam`, **no existe un script `*-patch.sql` separado**: `schema.sql` cumple ambos roles (creación inicial y aplicación incremental) en un solo archivo. Se recomienda mantener este patrón aditivo para cualquier evolución futura del esquema `assessment` (evitar `DROP`/`ALTER` destructivos directos), y considerar separar un script de *patch* dedicado si el esquema crece, siguiendo el precedente ya establecido por `ms_iam` en el mismo monorepo.

`maturity_data.sql`, aunque vive en la raíz de `ms_assessment/`, no es una migración del esquema `assessment`: es un script de siembra de datos de **catálogo** (`catalog.*`) para pruebas manuales del módulo de madurez. Debe mantenerse claramente diferenciado de cualquier futuro script de migración real del esquema propio del microservicio, para no confundir a un mantenedor que busque el historial de cambios de `assessment.*`.

## 6. Resumen de responsabilidades de mantenimiento por rol

| Rol | Responsabilidad de mantenimiento |
|---|---|
| Equipo de desarrollo backend | Evolución de los 28 casos de uso, mantenimiento de cobertura ≥80% (hoy no verificado en CI), actualización de `docs/openapi.yaml` ante cualquier cambio de contrato público o interno (impacto directo en `ms_reporting`) |
| DBA / DevOps | Aplicación de `schema.sql` en cada entorno (el microservicio no ejecuta DDL); corrección de la discrepancia de documentación sobre `spring.sql.init.mode` |
| Equipo de seguridad | Rotación de `INTERNAL_API_KEY` (compartida con `ms_catalog`/`ms_evidence`/`ms_iam`), revisión de la propagación del JWT del usuario hacia servicios aguas abajo (`jwtBearerForwardingInterceptor`), alineado con `docs/linea_base_seguridad_ISO27001.md` |
| Equipo de calidad / QA | Cerrar la brecha de pruebas en persistencia, adaptadores REST salientes y casos de uso de ciclo de vida; activar `check` en CI como *gate* real |
| Equipo de infraestructura | Mantenimiento del pipeline (`bitbucket-pipelines.yml`), gestión de despliegue en Railway, coordinación de arranque con las 4 dependencias externas del compose (`ms-org`, `ms-catalog`, `ms-evidence`, `ms-iam`) |
