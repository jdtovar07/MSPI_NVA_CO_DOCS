# ms_reporting — Mantenimiento

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_reporting` |
| Fecha del documento | 2026-08-19 |
| Alcance | Mantenimiento, gestión de versiones, observabilidad y mejoras futuras del microservicio `ms_reporting` |

---

## 1. Gestión de versiones

- El repositorio no expone un archivo de versión de aplicación explícito (no hay `version` declarado en `build.gradle` raíz ni en `settings.gradle`; `rootProject.name = 'MsReporting'` sin sufijo de versión). El versionado real, de existir, se gestiona por convención de tags/ramas de Git, no visible desde el contenido analizado (no es un repositorio Git accesible en este análisis — se documentó como carpeta plana bajo `MSPI_NVA_CO_MR_BACK/ms_reporting`).
- La imagen Docker se etiqueta de forma fija como `mspi/ms-reporting:dev` (`deployment/Dockerfile`, comentario de build) — no hay evidencia de un esquema de versionado semántico de imágenes (`:1.2.3`) ni de un registro de artefactos (Docker registry) referenciado en el repositorio.
- `docs/openapi.yaml` declara `info.version: 1.0.0`, congelado y sin evidencia de que se actualice junto con cambios de contrato — riesgo de desincronización entre el contrato documentado y el código real si no se disciplina su actualización manual (ver `03-Diseno.md`, DT-08).

## 2. Compatibilidad y evolución del esquema de datos

- El esquema `reporting` se gestiona con scripts SQL versionados (`schema.sql`), aplicados manualmente o mediante scripts de automatización externos (`docker-config/docker/postgres/scripts`), **no** mediante una herramienta de migraciones versionadas como Flyway o Liquibase — no se encontró ninguna de esas dependencias en los `build.gradle`. Cualquier cambio de esquema requiere coordinar manualmente la actualización de `schema.sql` (en `ms_reporting/`) y su copia espejo en `docker-config/docker/postgres/init/`, ambas debiendo mantenerse sincronizadas manualmente (riesgo de *drift* si se edita solo una copia).
- Las tablas `report_template`, `excel_workbook_template`, `excel_sheet_mapping` y `analytics_cache` existen en el esquema pero no tienen consumidor de código activo (ver `02-Analisis.md`/`03-Diseno.md`) — cualquier trabajo de mantenimiento futuro que decida activar plantillas configurables por base de datos deberá primero decidir si conserva, migra o elimina estas tablas y sus seeds asociados (`data.sql`, `MER-SEED-REPORTING.sql`), actualmente basados en un motor JasperReports abandonado.
- La plantilla `plantilla-referencia-mspi.xlsx` es un **recurso binario embebido en el classpath** (`domain/usecase/src/main/resources/reports/`). Actualizar el diseño de la hoja PORTADA (nuevos indicadores, cambio de layout) requiere: (a) reemplazar el archivo físico, y (b) revisar/ajustar las constantes de coordenadas fila/columna en `MspiPortadaTemplateFiller` (`DOMAIN_ROWS`, `PHVA_ROWS`, `MATURITY_ROWS`, `NIST_CHART_ROWS`, `nistTableRow`), que están *hardcodeadas* y romperían silenciosamente (escritura en la celda equivocada, sin error) si la plantilla cambia de estructura sin actualizar el código en paralelo. Es el punto de mantenimiento más frágil del microservicio.

## 3. Observabilidad

| Elemento | Estado real |
|---|---|
| Health check | `GET /actuator/health` — expuesto y público, consumido por `HEALTHCHECK` de Docker |
| Info de build | `GET /actuator/info` — expuesto y público |
| Trazabilidad de peticiones | `X-Trace-Id` vía `TraceIdFilter`, propagado a `MDC` y usado en `GlobalExceptionHandler` para incluir `traceId` en cada `ErrorResponse` |
| Logging | `logback.xml` presente en `applications/app-service/src/main/resources/`; sin evidencia de integración con un colector centralizado (ELK, Loki, etc.) en el código revisado |
| Métricas | No se encontró `micrometer-registry-*` (Prometheus, Datadog, etc.) en ninguno de los `build.gradle`; solo el endpoint genérico de Actuator, sin exportador de métricas configurado |
| Errores de job fallido | Consultables vía `GET /reports/jobs/{jobId}` → campo `errorMessage`; no hay alertamiento automático (correo, Slack, etc.) ante jobs `FAILED` |
| Progreso de job | Campo `progressPct`, actualizado en 3 puntos fijos (10/90/100) — no es un progreso granular real, sino un indicador de fase (iniciado / archivo generado / completado) |

**Ausencia notable**: no hay ningún mecanismo de **reconciliación de jobs "huérfanos"** — si el proceso JVM se reinicia (despliegue, caída) mientras un job está en `RUNNING`, ese job queda indefinidamente en ese estado en la base de datos (no hay un `@Scheduled` ni verificación al arranque que detecte y marque como `FAILED` los jobs `RUNNING` sin actividad reciente). Es un candidato claro de mejora de mantenimiento operativo.

## 4. Puntos de mantenimiento identificados (a partir del código)

1. **LibreOffice en imagen Jammy** (ver `06-Implementacion-Despliegue.md`, §2): la imagen `mspi/ms-reporting:dev` ya incluye `soffice`; el mantenimiento debe vigilar el tamaño de imagen, actualizaciones de `libreoffice-calc`/fuentes y que el entrypoint siga corrigiendo permisos del volumen `mspi_report_outputs` tras recrear el contenedor.
2. **Ausencia de pipeline CI/CD** (`bitbucket-pipelines.yml` no existe para este microservicio, a diferencia del resto del ecosistema MSPI) — tarea de mantenimiento de infraestructura de desarrollo pendiente, no solo de código de aplicación.
3. **Cobertura de pruebas insuficiente** (2 clases de prueba de un total de más de 20 clases con lógica relevante) frente a una regla de cobertura del 80% configurada pero previsiblemente incumplida — ver `05-Pruebas.md`.
4. **Seeds de base de datos desactualizados** (`data.sql`/`MER-SEED-REPORTING.sql` referencian un motor JasperReports y un libro Excel de 9 hojas que ya no corresponden a la implementación real de una sola hoja PORTADA) — limpieza pendiente para evitar confusión de futuros mantenedores.
5. **Tipos de reporte anunciados sin implementar** (`DIAGNOSTIC_WIDGET_PNG`, `DIAGNOSTIC_WIDGET_PDF` en el enum `ReportType` y en la tabla del README, sin rama de generación) — decidir si se implementan o se retiran del enum/documentación pública.
6. **`CatalogGateway` sin consumidor activo** — código muerto funcional (definido pero no invocado desde ningún caso de uso); candidato a eliminación o a completar la integración con `ms_catalog` si se retoma el plan de incluir la hoja "Escala" en el Excel.
7. **Excel comparativo incompleto** (`COMPARATIVE_DIAGNOSTIC_XLSX` solo usa la primera evaluación del listado, mientras el PDF comparativo sí las combina todas) — inconsistencia funcional entre los dos formatos del mismo tipo de reporte que debería resolverse o documentarse explícitamente de cara al usuario.
8. **Sin reconciliación de jobs huérfanos** tras reinicio del proceso (§3) — mejora de robustez operativa recomendada antes de un uso productivo con volumen significativo de reportes concurrentes.
9. **Umbral de brechas fijo (`threshold=60`)** *hardcodeado* en `ProcessReportJobUseCase.resolveGaps` — si el negocio requiere parametrizar el umbral desde la API pública, es un cambio localizado pero requiere extender `CreateReportJobCommand`/`CreateReportJobRequest` y el mapeo correspondiente.

## 5. Mejoras futuras sugeridas (no implementadas, alcance fuera de este análisis)

- Migrar la gestión del esquema `reporting` a una herramienta de migraciones versionadas (Flyway/Liquibase) para eliminar el riesgo de *drift* entre `ms_reporting/schema.sql` y su copia en `docker-config/`.
- Externalizar el mapeo de coordenadas de `MspiPortadaTemplateFiller` a un archivo de configuración (o a las tablas `excel_sheet_mapping`/`cell_map_json` ya existentes en el esquema pero sin uso), reduciendo el acoplamiento entre el diseño visual de la plantilla y el código Java.
- Añadir un job programado (`@Scheduled`) que detecte y marque como `FAILED` los jobs `RUNNING` con más de N minutos sin `finishedAt`, mitigando el riesgo de jobs huérfanos tras reinicios.
- Incorporar métricas de Micrometer (duración de generación por tipo de reporte, tasa de fallo de conversión LibreOffice, tamaño de cola del `reportJobExecutor`) para observabilidad operativa real.
- Completar o retirar los tipos `DIAGNOSTIC_WIDGET_PNG`/`DIAGNOSTIC_WIDGET_PDF` del enum `ReportType` según la decisión de producto vigente.
- Evaluar la integración real de `ms_catalog` (hoja "Escala") si el negocio la retoma, o eliminar `CatalogGateway`/`CatalogGatewayAdapter` si se confirma que quedó fuera de alcance definitivamente.
- Crear el `bitbucket-pipelines.yml` faltante, alineado con el patrón usado por los demás microservicios del repositorio (`Build App` + `Deploy to Railway` sobre rama `dev`), incorporando al menos la ejecución de `./gradlew test` dado el estado actual de cobertura.
