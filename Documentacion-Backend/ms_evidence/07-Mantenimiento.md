# ms_evidence — Mantenimiento

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_evidence` |
| Fecha del documento | 2026-08-19 |
| Alcance | Mantenimiento, versionamiento, monitoreo y mejoras futuras del microservicio `ms_evidence` |

---

## 1. Versionamiento

- **Versión de API**: `docs/openapi.yaml` declara `info.version: 1.0.0` — no se encontró historial de versiones anteriores ni un `CHANGELOG.md` propio del microservicio.
- **Versión de la aplicación**: no se encontró un `version` explícito en `build.gradle` (ni en el raíz ni en `applications/app-service/build.gradle`); Gradle usará por defecto `unspecified` salvo que se configure externamente (p. ej. por variable de CI), lo cual no está evidenciado en `bitbucket-pipelines.yml`.
- **Imagen Docker**: se etiqueta de forma fija como `mspi/ms-evidence:dev` tanto en `deployment/Dockerfile` (comentario de build) como en `docker-compose.apps.yml` — no hay evidencia de *tagging* semántico (`:1.0.0`, `:sha-...`) ni de un registro de imágenes versionadas; cada `docker compose up --build` sobrescribe la etiqueta `dev`.
- No existe `ROADMAP.md` ni control de versiones del esquema de base de datos (`schema.sql` es un único archivo sin migraciones incrementales tipo Flyway/Liquibase) — cualquier cambio de esquema requiere edición manual coordinada con el equipo de datos/DBA, tal como se declara en `01-Planificacion.md`.

## 2. Monitoreo y observabilidad reales

| Mecanismo | Estado | Detalle |
|---|---|---|
| `/actuator/health` | Implementado | Público (`permitAll()`), consumido por el `HEALTHCHECK` del Dockerfile |
| `/actuator/info` | Implementado | Público, sin contenido adicional configurado evidenciado (no se encontró `info.*` en `application.yaml`) |
| `X-Trace-Id` | Implementado | `TraceIdFilter` genera/propaga el trace ID vía MDC; se refleja en `ErrorResponse.meta.traceId` |
| Métricas Prometheus/Micrometer | **No implementado** | No se encontró `micrometer-registry-prometheus` en ningún `build.gradle` de `ms_evidence` (a diferencia de `ms_iam`, que sí lo declara) |
| Logging estructurado | Parcial | `logback.xml` presente en `applications/app-service/src/main/resources/`; `hibernate.show-sql: false` en producción |
| Alertas / dashboards | **No implementado** | Ninguna integración con Grafana, Datadog u otro APM evidenciada en el repositorio |

Dado que `ms_evidence` no expone métricas Prometheus, el monitoreo operativo real depende exclusivamente del `HEALTHCHECK` de Docker (estado binario sano/no-sano) y de logs sin agregación centralizada evidenciada.

## 3. Gestión del almacenamiento de archivos (mantenimiento operativo)

Al ser almacenamiento en filesystem local (no object storage gestionado), el mantenimiento del microservicio incluye responsabilidades operativas que un servicio como S3 delegaría al proveedor:

- **Backups**: no se encontró script ni configuración de respaldo del volumen `mspi_evidence_data` (ni en `docker-config/`, ni en el propio repositorio). El respaldo de `EVIDENCE_STORAGE_DIR` es responsabilidad externa no automatizada.
- **Crecimiento sin control de cuota**: no existe límite de almacenamiento total por evaluación u organización (solo límite de tamaño por archivo individual, ver `02-Analisis.md` §3). El crecimiento del volumen debe monitorearse manualmente.
- **Archivos huérfanos**: como se documenta en `02-Analisis.md` §6, un fallo entre `FileStorageGateway.store` y `EvidencePersistenceGateway.saveFile` puede dejar archivos físicos sin metadato asociado; no existe una tarea de limpieza (*garbage collection*) automatizada que reconcilie el filesystem con la tabla `evidence_file`.
- **Borrado lógico sin purga física garantizada**: `DeleteEvidenceFileUseCase` intenta el borrado físico, pero si falla solo registra una advertencia — el archivo físico puede persistir indefinidamente aunque el metadato esté marcado como borrado. No hay tarea programada de purga diferida.

## 4. Deuda técnica identificada

| Ítem | Impacto | Ubicación |
|---|---|---|
| Falta de pruebas unitarias en `domain/usecase`, `jpa-repository` y `app-service` | Alto — el 80% de cobertura exigido por `main.gradle` probablemente no se cumple en esos módulos; regresiones en reglas de negocio no se detectan automáticamente | ver `05-Pruebas.md` |
| Pipeline CI no ejecuta `test`/`check` | Alto — el build puede desplegar a Railway sin validar que las (pocas) pruebas existentes pasen | `bitbucket-pipelines.yml` |
| Sin compensación entre almacenamiento físico y metadato en `UploadEvidenceFileUseCase` | Medio — riesgo de archivos huérfanos ante fallos de base de datos tras escritura exitosa en disco | `domain/usecase/.../UploadEvidenceFileUseCase.java` |
| Adaptador de almacenamiento (`storage/`) ubicado en `app-service` en lugar de un módulo `driven-adapters` dedicado | Bajo/medio — dificulta reemplazar el mecanismo de almacenamiento (p. ej. migrar a S3) sin tocar el módulo ejecutable; contradice el diagrama aspiracional del propio `README.md` | `applications/app-service/src/main/java/co/com/mspi/storage/` |
| Dependencias declaradas sin prueba asociada (`archunit`, `object-mapper` en `jpa-repository`) | Bajo — indica trabajo de pruebas planeado y no completado | `app-service/build.gradle`, `jpa-repository/build.gradle` |
| Excepciones `IamServiceException`/`UserAlreadyExistsException` heredadas de la plantilla común sin uso real | Bajo — ruido en `GlobalExceptionHandler`, sin impacto funcional | `infrastructure/helpers/common` |
| Sin control de cuota de almacenamiento ni tarea de purga de archivos huérfanos/borrados | Medio (operativo) — crecimiento no acotado del volumen de datos | Almacenamiento físico |
| `traceId` de éxito no coincide con `X-Trace-Id` de la petición | Bajo — dificulta correlación completa de logs en flujos exitosos | Controladores REST (`UUID.randomUUID()` en cada respuesta 2xx) |

## 5. Mejoras futuras razonables (no implementadas, sugeridas a partir de las ausencias detectadas)

1. **Cobertura de pruebas del dominio**: priorizar pruebas unitarias de los 11 casos de uso (sin dependencias de Spring, dado que `usecase` no depende de framework), siguiendo el patrón ya usado en `ms_iam`.
2. **Migración incremental de esquema**: introducir Flyway o Liquibase para versionar cambios sobre `evidence.*` en lugar de un único `schema.sql` estático, facilitando auditoría de cambios de modelo de datos.
3. **Tarea de reconciliación de almacenamiento**: job periódico que compare `evidence_file.object_key` contra el contenido real de `EVIDENCE_STORAGE_DIR`, reportando/purgando archivos huérfanos y archivos lógicamente borrados cuyo borrado físico falló.
4. **Métricas Prometheus**: incorporar `micrometer-registry-prometheus` (ya usado en `ms_iam`) para exponer métricas de tamaño de archivos subidos, tasa de rechazo por validación de negocio, y latencia de subida/descarga.
5. **Extracción del adaptador de almacenamiento a un módulo Gradle propio** (`infrastructure/driven-adapters/filesystem`), habilitando en el futuro una implementación alternativa de `FileStorageGateway` (p. ej. S3/MinIO) sin modificar `app-service`.
6. **Activar `./gradlew check` en el pipeline** antes de `assemble`/`deploy`, para que la cobertura mínima y las pruebas existentes actúen como *quality gate* real.
7. **Cuota de almacenamiento por evaluación**: validar en `UploadEvidenceFileUseCase` (o en un caso de uso complementario) que la suma acumulada de archivos de una evaluación no exceda un límite configurable, evitando abuso del volumen compartido.

## 6. Ausencias explícitas (declaración final)

Este documento no encontró en el repositorio: `CHANGELOG.md`, `ROADMAP.md`, backlog o cronograma propio de `ms_evidence`, sistema de migraciones de base de datos, métricas Prometheus, backups automatizados del volumen de evidencias, ni pipeline de CI con etapa de pruebas. Todas las observaciones de este documento se basan exclusivamente en el código y la configuración presentes en `MSPI_NVA_CO_MR_BACK/ms_evidence` y en `MSPI_NVA_CO_MR_BACK/docker-config` a la fecha de este análisis.
